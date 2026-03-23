tolk 1.0

@pure
fun begin_cell(): builder
    asm "NEWC"

@pure
fun builder.end_cell(self): cell
    asm "ENDC"

fun cell.begin_parse(self): slice
    asm "CTOS"

fun my_address(): slice
    asm "MYADDR"

fun get_data(): cell
    asm "c4 PUSH"

fun set_data(c: cell)
    asm "c4 POP"

@pure
fun cell_hash(c: cell): int
    asm "HASHCU"

fun send_raw_message(msg: cell, mode: int)
    asm "SENDRAWMSG"

@pure
fun parse_std_addr(addr: slice): (int, int)
    asm "REWRITESTDADDR"

@pure
fun equal_slices(a: slice, b: slice): int
    asm "SDEQ"

@pure
fun builder_nullQ(b: builder): int
    asm "ISNULL"

@pure
fun muldiv(a: int, b: int, c: int): int
    asm "MULDIV"

@pure
fun workchain(): int
    asm "0 PUSHINT"

fun force_chain(addr: slice) {
    val (wc, _) = parse_std_addr(addr);
    assert (wc == workchain()) throw 333;
}

fun builder.store_uint(mutate self, x: int, len: int): self
    asm(x self len) "STUX"

fun builder.store_int(mutate self, x: int, len: int): self
    asm(x self len) "STIX"

fun builder.store_slice(mutate self, s: slice): self
    asm "STSLICER"

fun builder.store_ref(mutate self, c: cell): self
    asm(c self) "STREF"

fun builder.store_dict(mutate self, c: cell): self
    asm(c self) "STDICT"

fun builder.store_builder(mutate self, other: builder): self
    asm "STBR"

fun builder.store_coins(mutate self, x: int): self
    asm "STVARUINT16"

fun slice.load_uint(mutate self, len: int): int
    asm(-> 1 0) "LDUX"

fun slice.load_int(mutate self, len: int): int
    asm(-> 1 0) "LDIX"

fun slice.preload_uint(self, len: int): int
    asm "PLDUX"

fun slice.load_ref(mutate self): cell
    asm(-> 1 0) "LDREF"

fun slice.load_msg_addr(mutate self): slice
    asm(-> 1 0) "LDMSGADDR"

fun slice.load_coins(mutate self): int
    asm(-> 1 0) "LDVARUINT16"

fun slice.skip_bits(mutate self, len: int): void
    asm "SDSKIPFIRST"

@pure
fun slice_bits(s: slice): int
    asm "SBITS"

@pure
fun slice_emptyQ(s: slice): int
    asm "SEMPTY"

fun slice.load_maybe_ref(mutate self): cell
    asm(-> 1 0) "LDOPTREF"

@pure
fun slice_hash(s: slice): int
    asm "HASHSU"

fun builder.store_maybe_ref(mutate self, c: cell): self
    asm(c self) "STOPTREF"

@pure
fun idict_delete_get_min(dict: cell, key_len: int): (cell, int, slice, int)
    asm(-> 0 2 1 3) "DICTIREMMIN" "NULLSWAPIFNOT2"

@pure
fun udict_delete_get_min(dict: cell, key_len: int): (cell, int, slice, int)
    asm(-> 0 2 1 3) "DICTUREMMIN" "NULLSWAPIFNOT2"
