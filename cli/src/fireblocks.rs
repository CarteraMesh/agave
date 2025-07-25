use {
    crate::cli::CliConfig, solana_client::rpc_client::SerializableTransaction, solana_hash::Hash,
    solana_rpc_client::rpc_client::RpcClient, solana_rpc_client_api::client_error::Result,
    solana_signature::Signature, solana_transaction::Transaction,
};

pub fn try_sign(
    mut tx: Transaction,
    rpc: &RpcClient,
    config: &CliConfig,
    recent_blockhash: Hash,
) -> Result<Signature> {
    tx.try_sign(&config.signers, recent_blockhash)?;
    let _ = rpc.confirm_transaction_with_spinner(
        tx.get_signature(),
        &recent_blockhash,
        config.commitment,
    )?;
    Ok(*tx.get_signature())
}
/// Macro to generate fireblocks signing code with configurable recent_blockhash variable name
macro_rules! try_fireblocks_sign {
    ($tx:expr, $rpc_client:expr, $config:expr, $recent_blockhash_var:expr) => {
        if $config.keypair_path.contains("fireblocks") {
            let result =
                crate::fireblocks::try_sign($tx, &$rpc_client, &$config, $recent_blockhash_var);
            return log_instruction_custom_error::<SystemError>(result, $config);
        }
    };
}

pub(crate) use try_fireblocks_sign;
