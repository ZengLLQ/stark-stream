use crate::math::calculate_streamed_amount;

#[test]
fn test_linear_streaming_calculation() {
    let deposit: u256 = 10000;
    let start_time: u64 = 1000;
    let stop_time: u64 = 2000;
    let cliff_time: u64 = 1000; // No cliff

    // Before start: 0
    let amt_pre = calculate_streamed_amount(deposit, start_time, stop_time, cliff_time, 500);
    assert(amt_pre == 0, 'Should be 0 before start');

    // Exactly at start: 0
    let amt_start = calculate_streamed_amount(deposit, start_time, stop_time, cliff_time, 1000);
    assert(amt_start == 0, 'Should be 0 at start');

    // Halfway (timestamp 1500): exactly 5000
    let amt_half = calculate_streamed_amount(deposit, start_time, stop_time, cliff_time, 1500);
    assert(amt_half == 5000, 'Should be 5000 halfway');

    // Three quarters (timestamp 1750): exactly 7500
    let amt_3q = calculate_streamed_amount(deposit, start_time, stop_time, cliff_time, 1750);
    assert(amt_3q == 7500, 'Should be 7500 at 3/4');

    // At stop time: exactly 10000
    let amt_stop = calculate_streamed_amount(deposit, start_time, stop_time, cliff_time, 2000);
    assert(amt_stop == 10000, 'Should be 10000 at stop');

    // Past stop time: still exactly 10000
    let amt_past = calculate_streamed_amount(deposit, start_time, stop_time, cliff_time, 2500);
    assert(amt_past == 10000, 'Should be 10000 past stop');
}

#[test]
fn test_cliff_vesting_schedule() {
    let deposit: u256 = 12000;
    let start_time: u64 = 1000;
    let stop_time: u64 = 2200; // Duration 1200 seconds -> 10 tokens/sec
    let cliff_time: u64 = 1300; // 300 second cliff (1/4 duration)

    // Before cliff (timestamp 1299): strictly 0
    let amt_before_cliff = calculate_streamed_amount(deposit, start_time, stop_time, cliff_time, 1299);
    assert(amt_before_cliff == 0, 'Should be 0 before cliff');

    // At cliff (timestamp 1300): releases initial 3000 tokens instantly
    let amt_at_cliff = calculate_streamed_amount(deposit, start_time, stop_time, cliff_time, 1300);
    assert(amt_at_cliff == 3000, 'Should release 3000 at cliff');

    // After cliff (timestamp 1600): 600 elapsed -> 6000 tokens
    let amt_after_cliff = calculate_streamed_amount(deposit, start_time, stop_time, cliff_time, 1600);
    assert(amt_after_cliff == 6000, 'Should release 6000 after cliff');
}

#[test]
fn test_conservation_of_funds_invariant() {
    let deposit: u256 = 500000;
    let start_time: u64 = 5000;
    let stop_time: u64 = 10000;
    let cliff_time: u64 = 6000;

    // Test across a sequence of timestamps
    let timestamps: Array<u64> = array![4000, 5000, 5500, 6000, 7500, 9999, 10000, 15000];
    let mut i: usize = 0;

    while i < timestamps.len() {
        let t = *timestamps.at(i);
        let recipient_streamed = calculate_streamed_amount(deposit, start_time, stop_time, cliff_time, t);
        let sender_remaining = deposit - recipient_streamed;

        // Invariant: recipient_streamed + sender_remaining == deposit
        assert(recipient_streamed + sender_remaining == deposit, 'Invariant broken');
        assert(recipient_streamed <= deposit, 'Streamed exceeds deposit');
        i += 1;
    }
}
