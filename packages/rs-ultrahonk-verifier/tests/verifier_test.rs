use soroban_sdk::{testutils::Ledger, Bytes, Env};
use std::{fs, path::Path};
use ultrahonk_soroban_verifier::field::Field;
use ultrahonk_soroban_verifier::utils::load_proof;
use ultrahonk_soroban_verifier::UltraHonkVerifier;

fn run(dir: &str) -> Result<(), String> {
    let path = Path::new(dir);
    let env = Env::default();
    env.ledger().set_protocol_version(26);
    env.cost_estimate().budget().reset_unlimited();

    // Proof bytes
    let proof_bytes: Vec<u8> = fs::read(path.join("proof")).map_err(|e| e.to_string())?;
    let proof = Bytes::from_slice(&env, &proof_bytes);

    // Use binary VK
    let vk_bytes = fs::read(path.join("vk")).map_err(|e| e.to_string())?;
    let vk = Bytes::from_slice(&env, &vk_bytes);
    let verifier = UltraHonkVerifier::new(&env, &vk).map_err(|e| format!("{e:?}"))?;

    // Public inputs bytes
    let public_inputs = fs::read(path.join("public_inputs")).map_err(|e| e.to_string())?;
    let public_inputs = Bytes::from_slice(&env, &public_inputs);
    verifier
        .verify(&env, &proof, &public_inputs)
        .map_err(|e| format!("{e:?}"))?;
    Ok(())
}

#[test]
fn simple_circuit_proof_verifies() -> Result<(), String> {
    run("circuits/simple_circuit/target")
}

#[test]
fn fib_chain_proof_verifies() -> Result<(), String> {
    run("circuits/fib_chain/target")
}

/// Sanity: first sumcheck row u[0]+u[1] must equal 0 (matches raw proof bytes mod r).
#[test]
fn simple_circuit_first_sumcheck_row_sums_to_zero() {
    let env = Env::default();
    env.ledger().set_protocol_version(26);
    let bytes = include_bytes!("../circuits/simple_circuit/target/proof");
    let proof_b = Bytes::from_slice(&env, bytes.as_slice());
    let proof = load_proof(&env, &proof_b);
    let sum = proof.sumcheck_univariates[0][0].clone() + proof.sumcheck_univariates[0][1].clone();
    assert!(
        Field::is_zero(&sum),
        "expected 0 got {}",
        hex::encode(sum.to_bytes().to_array())
    );
}
