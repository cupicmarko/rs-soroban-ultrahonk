#[cfg(not(feature = "std"))]
use alloc::{borrow::ToOwned, string::String};
use core::array;
use soroban_sdk::{BytesN, Env, U256};

#[inline(always)]
fn normalize_hex(s: &str) -> String {
    let raw = s.trim_start_matches("0x");
    if raw.len() & 1 == 1 {
        let mut out = String::with_capacity(raw.len() + 1);
        out.push('0');
        out.push_str(raw);
        out
    } else {
        raw.to_owned()
    }
}

pub type Fr = soroban_sdk::crypto::bn254::Bn254Fr;


/// Montgomery batch inversion: compute all inverses of `vals[..n]` using a
/// single field inversion + 3*(n-1) multiplications, writing results into `out`.
/// Both `vals` and `out` must have the same length.
/// Returns an error if any element is zero (the product is non-invertible).
pub fn batch_inverse(vals: &[Fr], out: &mut [Fr]) -> Result<(), &'static str> {
    let n = vals.len();
    assert_eq!(n, out.len(), "batch_inverse: len mismatch");

    if n == 0 {
        return Ok(());
    }

    // 1) Build prefix products in `out`: out[i] = vals[0] * vals[1] * ... * vals[i]
    out[0] = vals[0].clone();
    for i in 1..n {
        out[i] = out[i - 1].clone() * vals[i].clone();
    }

    // 2) Invert the total product
    let mut inv_acc = out[n - 1]
        .inv();

    // 3) Sweep back to recover individual inverses
    for i in (1..n).rev() {
        out[i] = inv_acc.clone() * out[i - 1].clone();
        inv_acc = inv_acc * vals[i].clone();
    }
    out[0] = inv_acc;
    Ok(())
}

pub trait Field: Sized + Clone {
    fn zero(env: &Env) -> Self;
    fn one(env: &Env) -> Self;
    fn is_zero(&self) -> bool;
    fn from_u32(env: &Env, x: u32) -> Self;
    fn from_u128(env: &Env, x: u128) -> Self;
    fn from_array(env: &Env, bytes: &[u8; 32]) -> Self;
    fn zero_array<const N: usize>(env: &Env) -> [Self; N] {
        array::repeat(Self::zero(env))
    }
}

impl Field for Fr {
    fn zero(env: &Env) -> Self {
        Self::from_u256(U256::from_u32(env, 0))
    }

    fn one(env: &Env) -> Self {
        Self::from_u256(U256::from_u32(env, 1))
    }

    fn is_zero(&self) -> bool {
        self.eq(&Self::zero(self.env()))
    }

    fn from_u32(env: &Env, x: u32) -> Self {
        Self::from_u256(U256::from_u32(env, x))
    }

    fn from_u128(env: &Env, x: u128) -> Self {
        Self::from_u256(U256::from_u128(env, x))
    }

    fn from_array(env: &Env, bytes: &[u8; 32]) -> Self {
        Fr::from_bytes(BytesN::from_array(env, bytes))
    }
}