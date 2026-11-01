#[starknet::contract]
pub mod StarkStreamContract {
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::types::Stream;
    use crate::math::calculate_streamed_amount;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        StreamCreated: StreamCreated,
        StreamWithdrawn: StreamWithdrawn,
        StreamCancelled: StreamCancelled,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StreamCreated {
        #[key]
        pub stream_id: u64,
        #[key]
        pub sender: ContractAddress,
        #[key]
        pub recipient: ContractAddress,
        pub deposit: u256,
        pub start_time: u64,
        pub stop_time: u64,
        pub cliff_time: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StreamWithdrawn {
        #[key]
        pub stream_id: u64,
        #[key]
        pub recipient: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StreamCancelled {
        #[key]
        pub stream_id: u64,
        #[key]
        pub sender: ContractAddress,
        #[key]
        pub recipient: ContractAddress,
        pub sender_refund: u256,
        pub recipient_payout: u256,
    }

    #[storage]
    struct Storage {
        pub stream_count: u64,
        pub streams: Map<u64, Stream>,
    }

    #[generate_trait]
    pub impl StarkStreamImpl of IStarkStream {
        fn create_stream(
            ref self: ContractState,
            recipient: ContractAddress,
            deposit: u256,
            token: ContractAddress,
            start_time: u64,
            stop_time: u64,
            cliff_time: u64,
        ) -> u64 {
            let caller = get_caller_address();
            assert(deposit > 0, 'Deposit must be positive');
            assert(start_time < stop_time, 'Start must be before stop');
            assert(cliff_time <= stop_time, 'Cliff must be <= stop');

            let stream_id = self.stream_count.read() + 1;
            self.stream_count.write(stream_id);

            let stream = Stream {
                sender: caller,
                recipient,
                deposit,
                token,
                start_time,
                stop_time,
                cliff_time,
                withdrawn_amount: 0,
                is_cancelled: false,
            };

            self.streams.write(stream_id, stream);

            self.emit(Event::StreamCreated(StreamCreated {
                stream_id,
                sender: caller,
                recipient,
                deposit,
                start_time,
                stop_time,
                cliff_time,
            }));

            stream_id
        }

        fn withdraw_from_stream(
            ref self: ContractState,
            stream_id: u64,
            amount: u256,
        ) -> u256 {
            let caller = get_caller_address();
            let mut stream = self.streams.read(stream_id);
            assert(!stream.is_cancelled, 'Stream is cancelled');
            assert(caller == stream.recipient, 'Caller is not recipient');

            let current_time = get_block_timestamp();
            let available = self.recipient_balance_at(stream_id, current_time);
            assert(amount <= available, 'Amount exceeds available');

            stream.withdrawn_amount += amount;
            self.streams.write(stream_id, stream);

            self.emit(Event::StreamWithdrawn(StreamWithdrawn {
                stream_id,
                recipient: caller,
                amount,
            }));

            amount
        }

        fn cancel_stream(ref self: ContractState, stream_id: u64) -> (u256, u256) {
            let caller = get_caller_address();
            let mut stream = self.streams.read(stream_id);
            assert(!stream.is_cancelled, 'Stream already cancelled');
            assert(caller == stream.sender || caller == stream.recipient, 'Unauthorized to cancel');

            let current_time = get_block_timestamp();
            let recipient_payout = self.recipient_balance_at(stream_id, current_time);
            let total_streamed = calculate_streamed_amount(
                stream.deposit,
                stream.start_time,
                stream.stop_time,
                stream.cliff_time,
                current_time,
            );
            let sender_refund = stream.deposit - total_streamed;

            stream.is_cancelled = true;
            stream.withdrawn_amount = total_streamed;
            self.streams.write(stream_id, stream);

            self.emit(Event::StreamCancelled(StreamCancelled {
                stream_id,
                sender: stream.sender,
                recipient: stream.recipient,
                sender_refund,
                recipient_payout,
            }));

            (sender_refund, recipient_payout)
        }

        fn get_stream(self: @ContractState, stream_id: u64) -> Stream {
            self.streams.read(stream_id)
        }

        fn recipient_balance_at(self: @ContractState, stream_id: u64, timestamp: u64) -> u256 {
            let stream = self.streams.read(stream_id);
            if stream.is_cancelled {
                return 0;
            }
            let total_streamed = calculate_streamed_amount(
                stream.deposit,
                stream.start_time,
                stream.stop_time,
                stream.cliff_time,
                timestamp,
            );
            if total_streamed <= stream.withdrawn_amount {
                0
            } else {
                total_streamed - stream.withdrawn_amount
            }
        }

        fn sender_balance_at(self: @ContractState, stream_id: u64, timestamp: u64) -> u256 {
            let stream = self.streams.read(stream_id);
            if stream.is_cancelled {
                return 0;
            }
            let total_streamed = calculate_streamed_amount(
                stream.deposit,
                stream.start_time,
                stream.stop_time,
                stream.cliff_time,
                timestamp,
            );
            stream.deposit - total_streamed
        }
    }
}
