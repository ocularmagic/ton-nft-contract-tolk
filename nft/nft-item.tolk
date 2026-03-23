tolk 1.2

import "imports/compat"
import "imports/op-codes"

@pure
fun min_tons_for_storage(): int
    asm "50000000 PUSHINT"

fun load_data(): (int, int, slice, slice, cell) {
    var ds = get_data().begin_parse();
    val index = ds.load_uint(64);
    val collection_address = ds.load_msg_addr();
    if (slice_bits(ds) > 0) {
        return (-1, index, collection_address, ds.load_msg_addr(), ds.load_ref());
    } else {
        return (0, index, collection_address, begin_cell().end_cell().begin_parse(), begin_cell().end_cell());
    }
}

fun store_data(index: int, collection_address: slice, owner_address: slice, content: cell) {
    set_data(
        begin_cell()
            .store_uint(index, 64)
            .store_slice(collection_address)
            .store_slice(owner_address)
            .store_ref(content)
            .end_cell()
    );
}

fun send_msg(to_address: slice, amount: int, op: int, query_id: int, payload: builder, send_mode: int, has_payload: int) {
    var msg = begin_cell()
        .store_uint(0x10, 6)
        .store_slice(to_address)
        .store_coins(amount)
        .store_uint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
        .store_uint(op, 32)
        .store_uint(query_id, 64);

    if (has_payload != 0) {
        msg.store_builder(payload);
    }

    send_raw_message(msg.end_cell(), send_mode);
}

fun transfer_ownership(my_balance: int, index: int, collection_address: slice, owner_address: slice, content: cell, sender_address: slice, query_id: int, msg_body: slice, fwd_fees: int) {
    assert (equal_slices(sender_address, owner_address)) throw 401;

    val new_owner_address = msg_body.load_msg_addr();
    force_chain(new_owner_address);
    val response_destination = msg_body.load_msg_addr();
    msg_body.load_int(1);
    val forward_amount = msg_body.load_coins();
    assert (slice_bits(msg_body) >= 1) throw 708;

    var rest_amount = my_balance - min_tons_for_storage();
    if (forward_amount != 0) {
        rest_amount -= forward_amount + fwd_fees;
    }

    val need_response = response_destination.preload_uint(2) != 0;
    if (need_response) {
        rest_amount -= fwd_fees;
    }

    assert (rest_amount >= 0) throw 402;

    if (forward_amount != 0) {
        send_msg(
            new_owner_address,
            forward_amount,
            OP_OWNERSHIP_ASSIGNED,
            query_id,
            begin_cell().store_slice(owner_address).store_slice(msg_body),
            1,
            1
        );
    }

    if (need_response) {
        force_chain(response_destination);
        send_msg(response_destination, rest_amount, OP_EXCESSES, query_id, begin_cell(), 1, 0);
    }

    store_data(index, collection_address, new_owner_address, content);
}

fun onInternalMessage(my_balance: int, msg_value: int, msg_full: cell, msg_body: slice) {
    if (slice_emptyQ(msg_body) != 0) {
        return;
    }

    var cs = msg_full.begin_parse();
    val flags = cs.load_uint(4);
    if ((flags & 1) != 0) {
        return;
    }

    val sender_address = cs.load_msg_addr();
    cs.load_msg_addr();
    cs.load_coins();
    cs.skip_bits(1);
    cs.load_coins();
    val fwd_fee = muldiv(cs.load_coins(), 3, 2);

    val (init, index, collection_address, owner_address, content) = load_data();
    if (init == 0) {
        assert (equal_slices(collection_address, sender_address)) throw 405;
        store_data(index, collection_address, msg_body.load_msg_addr(), msg_body.load_ref());
        return;
    }

    val op = msg_body.load_uint(32);
    val query_id = msg_body.load_uint(64);

    if (op == OP_TRANSFER) {
        transfer_ownership(my_balance, index, collection_address, owner_address, content, sender_address, query_id, msg_body, fwd_fee);
        return;
    }

    if (op == OP_GET_STATIC_DATA) {
        send_msg(
            sender_address,
            0,
            OP_REPORT_STATIC_DATA,
            query_id,
            begin_cell().store_uint(index, 256).store_slice(collection_address),
            64,
            1
        );
        return;
    }

    throw 0xffff;
}

get fun get_nft_data(): (int, int, slice, slice, cell) {
    return load_data();
}
