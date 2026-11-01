pub fn calculate_streamed_amount(
    deposit: u256,
    start_time: u64,
    stop_time: u64,
    cliff_time: u64,
    current_time: u64,
) -> u256 {
    if current_time < start_time || current_time < cliff_time {
        return 0;
    }
    if current_time >= stop_time {
        return deposit;
    }

    let duration: u256 = (stop_time - start_time).into();
    let elapsed: u256 = (current_time - start_time).into();

    (deposit * elapsed) / duration
}
