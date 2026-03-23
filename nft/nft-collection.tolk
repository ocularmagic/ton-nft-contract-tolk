tolk 1.0

import "imports/compat"
import "imports/op-codes"

fun load_data(): (slice, int, cell, cell, cell) {
    var ds = get_data().begin_parse();
    return (
        ds.load_msg_addr(),
        ds.load_uint(64),
        ds.load_ref(),
        ds.load_ref(),
        ds.load_ref()
    );
}

fun save_data(owner_address: slice, next_item_index: int, content: cell, nft_item_code: cell, royalty_params: cell) {
    set_data(
        begin_cell()
            .store_slice(owner_address)
            .store_uint(next_item_index, 64)
            .store_ref(content)
            .store_ref(nft_item_code)
            .store_ref(royalty_params)
            .end_cell()
    );
}

fun calculate_nft_item_state_init(item_index: int, nft_item_code: cell): cell {
    val data = begin_cell()
        .store_uint(item_index, 64)
        .store_slice(my_address())
        .end_cell();
    return begin_cell()
        .store_uint(0, 2)
        .store_dict(nft_item_code)
        .store_dict(data)
        .store_uint(0, 1)
        .end_cell();
}

fun calculate_nft_item_address(wc: int, state_init: cell): slice {
    return begin_cell()
        .store_uint(4, 3)
        .store_int(wc, 8)
        .store_uint(cell_hash(state_init), 256)
        .end_cell()
        .begin_parse();
}

fun deploy_nft_item(item_index: int, nft_item_code: cell, amount: int, nft_content: cell) {
    val state_init = calculate_nft_item_state_init(item_index, nft_item_code);
    val nft_address = calculate_nft_item_address(workchain(), state_init);
    val msg = begin_cell()
        .store_uint(0x18, 6)
        .store_slice(nft_address)
        .store_coins(amount)
        .store_uint(4 + 2 + 1, 1 + 4 + 4 + 64 + 32 + 1 + 1 + 1)
        .store_ref(state_init)
        .store_ref(nft_content);
    send_raw_message(msg.end_cell(), 1);
}

fun send_royalty_params(to_address: slice, query_id: int, data: slice) {
    val msg = begin_cell()
        .store_uint(0x10, 6)
        .store_slice(to_address)
        .store_coins(0)
        .store_uint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
        .store_uint(OP_REPORT_ROYALTY_PARAMS, 32)
        .store_uint(query_id, 64)
        .store_slice(data);
    send_raw_message(msg.end_cell(), 64);
}

fun onInternalMessage(msgFull: cell, msgBody: slice) {
    if (slice_emptyQ(msgBody) != 0) {
        return;
    }

    var cs = msgFull.begin_parse();
    val flags = cs.load_uint(4);
    if ((flags & 1) != 0) {
        return;
    }

    val sender_address = cs.load_msg_addr();
    val op = msgBody.load_uint(32);
    val query_id = msgBody.load_uint(64);

    var (owner_address, next_item_index, content, nft_item_code, royalty_params) = load_data();

    if (op == OP_GET_ROYALTY_PARAMS) {
        send_royalty_params(sender_address, query_id, royalty_params.begin_parse());
        return;
    }

    assert (equal_slices(sender_address, owner_address)) throw 401;

    if (op == OP_DEPLOY_ITEM) {
        val item_index = msgBody.load_uint(64);
        assert (item_index <= next_item_index) throw 402;
        val is_last = item_index == next_item_index;
        deploy_nft_item(item_index, nft_item_code, msgBody.load_coins(), msgBody.load_ref());
        if (is_last) {
            next_item_index += 1;
            save_data(owner_address, next_item_index, content, nft_item_code, royalty_params);
        }
        return;
    }

    if (op == OP_BATCH_DEPLOY_ITEM) {
        var counter = 0;
        var deploy_list = msgBody.load_ref();
        var has_item = 1;
        do {
            var item_index = 0;
            var item = null as slice;
            (deploy_list, item_index, item, has_item) = udict_delete_get_min(deploy_list, 64);
            if (has_item != 0) {
                counter += 1;
                assert (counter < 250) throw 399;
                assert (item_index <= next_item_index) throw (403 + counter);
                deploy_nft_item(item_index, nft_item_code, item.load_coins(), item.load_ref());
                if (item_index == next_item_index) {
                    next_item_index += 1;
                }
            }
        } while (has_item != 0);
        save_data(owner_address, next_item_index, content, nft_item_code, royalty_params);
        return;
    }

    if (op == OP_CHANGE_OWNER) {
        val new_owner = msgBody.load_msg_addr();
        save_data(new_owner, next_item_index, content, nft_item_code, royalty_params);
        return;
    }

    throw 0xffff;
}

get fun get_collection_data(): (int, cell, slice) {
    val (owner_address, next_item_index, content, _, _) = load_data();
    var cs = content.begin_parse();
    return (next_item_index, cs.load_ref(), owner_address);
}

get fun get_nft_address_by_index(index: int): slice {
    val (_, _, _, nft_item_code, _) = load_data();
    val state_init = calculate_nft_item_state_init(index, nft_item_code);
    return calculate_nft_item_address(workchain(), state_init);
}

get fun royalty_params(): (int, int, slice) {
    val (_, _, _, _, royalty) = load_data();
    var rs = royalty.begin_parse();
    return (rs.load_uint(16), rs.load_uint(16), rs.load_msg_addr());
}

get fun get_nft_content(index: int, individual_nft_content: cell): cell {
    val (_, _, content, _, _) = load_data();
    var cs = content.begin_parse();
    cs.load_ref();
    val common_content = cs.load_ref().begin_parse();
    return begin_cell()
        .store_uint(1, 8)
        .store_slice(common_content)
        .store_ref(individual_nft_content)
        .end_cell();
}
