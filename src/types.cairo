use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Stream {
    pub sender: ContractAddress,
    pub recipient: ContractAddress,
    pub deposit: u256,
    pub token: ContractAddress,
    pub start_time: u64,
    pub stop_time: u64,
    pub cliff_time: u64,
    pub withdrawn_amount: u256,
    pub is_cancelled: bool,
}
