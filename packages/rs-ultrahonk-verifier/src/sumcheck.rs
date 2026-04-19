//! Sum-check verifier

use soroban_sdk::Env;
use crate::{
    field::{batch_inverse, Fr},
    relations::accumulate_relation_evaluations,
    types::{Transcript, VerificationKey, BATCHED_RELATION_PARTIAL_LENGTH},
};
use crate::field::Field;

/// Distinguish which sumcheck `u(0)+u(1)=target` check failed (log_n <= 28).
const SUMCHECK_ROUND_FAILED: [&str; 28] = [
    "sumcheck round 0",
    "sumcheck round 1",
    "sumcheck round 2",
    "sumcheck round 3",
    "sumcheck round 4",
    "sumcheck round 5",
    "sumcheck round 6",
    "sumcheck round 7",
    "sumcheck round 8",
    "sumcheck round 9",
    "sumcheck round 10",
    "sumcheck round 11",
    "sumcheck round 12",
    "sumcheck round 13",
    "sumcheck round 14",
    "sumcheck round 15",
    "sumcheck round 16",
    "sumcheck round 17",
    "sumcheck round 18",
    "sumcheck round 19",
    "sumcheck round 20",
    "sumcheck round 21",
    "sumcheck round 22",
    "sumcheck round 23",
    "sumcheck round 24",
    "sumcheck round 25",
    "sumcheck round 26",
    "sumcheck round 27",
];

const BARY_BYTES: [[u8; 32]; BATCHED_RELATION_PARTIAL_LENGTH] = [
    [
        0x30, 0x64, 0x4e, 0x72, 0xe1, 0x31, 0xa0, 0x29, 0xb8, 0x50, 0x45, 0xb6, 0x81, 0x81, 0x58,
        0x5d, 0x28, 0x33, 0xe8, 0x48, 0x79, 0xb9, 0x70, 0x91, 0x43, 0xe1, 0xf5, 0x93, 0xef, 0xff,
        0xec, 0x51,
    ],
    [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x02, 0xd0,
    ],
    [
        0x30, 0x64, 0x4e, 0x72, 0xe1, 0x31, 0xa0, 0x29, 0xb8, 0x50, 0x45, 0xb6, 0x81, 0x81, 0x58,
        0x5d, 0x28, 0x33, 0xe8, 0x48, 0x79, 0xb9, 0x70, 0x91, 0x43, 0xe1, 0xf5, 0x93, 0xef, 0xff,
        0xff, 0x11,
    ],
    [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x90,
    ],
    [
        0x30, 0x64, 0x4e, 0x72, 0xe1, 0x31, 0xa0, 0x29, 0xb8, 0x50, 0x45, 0xb6, 0x81, 0x81, 0x58,
        0x5d, 0x28, 0x33, 0xe8, 0x48, 0x79, 0xb9, 0x70, 0x91, 0x43, 0xe1, 0xf5, 0x93, 0xef, 0xff,
        0xff, 0x71,
    ],
    [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0xf0,
    ],
    [
        0x30, 0x64, 0x4e, 0x72, 0xe1, 0x31, 0xa0, 0x29, 0xb8, 0x50, 0x45, 0xb6, 0x81, 0x81, 0x58,
        0x5d, 0x28, 0x33, 0xe8, 0x48, 0x79, 0xb9, 0x70, 0x91, 0x43, 0xe1, 0xf5, 0x93, 0xef, 0xff,
        0xfd, 0x31,
    ],
    [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x13, 0xb0,
    ],
];

/// Check if the sum of two univariates equals the target value
#[inline(always)]
fn check_sum(round_univariate: &[Fr], round_target: Fr) -> bool {
    let total_sum = round_univariate[0].clone() + round_univariate[1].clone();
    total_sum == round_target
}

/// Calculate next target value for the sum-check using batch inversion.
/// Instead of 8 individual inversions per round, uses Montgomery's trick
/// to compute all 8 with a single inversion + 21 multiplications.
#[inline(always)]
fn compute_next_target_sum(
    env: &Env,
    round_univariate: &[Fr],
    round_challenge: Fr,
) -> Result<Fr, &'static str> {
    // B(χ) = ∏ (χ - i) for i in 0..8
    // Also collect denominators for batch inversion
    let mut denoms = Fr::zero_array::<BATCHED_RELATION_PARTIAL_LENGTH>(env);
    let mut inv_denoms = denoms.clone();
    let mut b_poly = Fr::one(env);
    for i in 0..BATCHED_RELATION_PARTIAL_LENGTH {
        let diff = round_challenge.clone() - Fr::from_u128(env, i as u128);
        b_poly = b_poly * diff.clone();
        denoms[i] = Fr::from_array(env, &BARY_BYTES[i]) * diff;
    }

    // Batch invert all 8 denominators with a single Fr::inverse()
    batch_inverse(&denoms, &mut inv_denoms)
        .map_err(|_| "sumcheck: barycentric denominator is zero")?;

    // Σ u_i * inv_denom_i
    let mut acc = Fr::zero(env);
    for i in 0..BATCHED_RELATION_PARTIAL_LENGTH {
        acc = acc + (round_univariate[i].clone() * inv_denoms[i].clone());
    }

    Ok(b_poly * acc)
}

#[inline(always)]
fn partially_evaluate_pow(
    env: &Env,
    gate_challenge: Fr,
    pow_partial_evaluation: Fr,
    round_challenge: Fr,
) -> Fr {
    pow_partial_evaluation * (Fr::one(env) + round_challenge * (gate_challenge - Fr::one(env)))
}

pub fn verify_sumcheck(
    env: &Env,
    proof: &crate::types::Proof,
    tp: &Transcript,
    vk: &VerificationKey,
) -> Result<(), &'static str> {
    let log_n = vk.log_circuit_size as usize;
    let mut round_target = Fr::zero(env);
    let mut pow_partial_evaluation = Fr::one(env);

    // 1) Each round sum check and next target/pow calculation
    for round in 0..log_n {
        let round_univariate = &proof.sumcheck_univariates[round];

        if !check_sum(round_univariate, round_target.clone()) {
            return Err(SUMCHECK_ROUND_FAILED[round.min(SUMCHECK_ROUND_FAILED.len() - 1)]);
        }

        let round_challenge = tp.sumcheck_u_challenges[round].clone();
        round_target = compute_next_target_sum(env, round_univariate, round_challenge.clone())?;
        pow_partial_evaluation = partially_evaluate_pow(env,
                                                        tp.gate_challenges[round].clone(),
            pow_partial_evaluation,
            round_challenge,
        );
    }

    // 2) Final relation summation
    let grand_honk_relation_sum = accumulate_relation_evaluations(env,
                                                                  &proof.sumcheck_evaluations,
        &tp.rel_params,
        &tp.alphas,
        pow_partial_evaluation,
    );

    if grand_honk_relation_sum == round_target {
        Ok(())
    } else {
        crate::trace!("===== SUMCHECK FINAL CHECK FAILED =====");
        crate::trace!(
            "grand_relation = 0x{}",
            hex::encode(grand_honk_relation_sum.to_bytes())
        );
        crate::trace!("target = 0x{}", hex::encode(round_target.to_bytes()));
        crate::trace!(
            "difference = 0x{}",
            hex::encode((grand_honk_relation_sum - round_target).to_bytes())
        );
        crate::trace!("======================================");
        Err("sumcheck final mismatch")
    }
}
