// noc_api_wrapper.sv - Unified user-facing API with explicit source (master_id) + destination
class noc_api_wrapper extends uvm_object;

    `uvm_object_utils(noc_api_wrapper)

    static local noc_api_wrapper  m_inst;
    noc_virtual_sequencer        m_vseqr;
    noc_env_cfg                  m_cfg;
    bit                          m_initialized;

    function new(string name = "noc_api_wrapper");
        super.new(name);
        m_initialized = 1'b0;
    endfunction

    static function noc_api_wrapper get();
        if (m_inst == null) begin
            m_inst = new();
        end
        return m_inst;
    endfunction

    function void set_virtual_sequencer(noc_virtual_sequencer vseqr);
        m_vseqr = vseqr;
    endfunction

    function void set_config(noc_env_cfg cfg);
        m_cfg = cfg;
    endfunction

    function void init(noc_virtual_sequencer vseqr, noc_env_cfg cfg);
        m_vseqr = vseqr;
        m_cfg   = cfg;
        m_initialized = 1'b1;
    endfunction

    // =====================================================
    // Public API: noc_read
    //   master_id  : source master (required, -1 = auto-select first accessible)
    //   addr       : destination address (required)
    //   slave_name : destination slave name hint (optional, speeds lookup)
    // =====================================================
    task noc_read(
        input  bit [63:0]    addr,
        output bit [1023:0]  data,
        input  bit [2:0]     size        = 3'b010,
        input  int           master_id   = -1,
        input  string        slave_name  = "",
        input  bit [2:0]     prot        = 3'b000,
        input  int           timeout_ns  = 10000
    );
        noc_unified_transaction txn;
        bit ok;

        check_init("noc_read");

        txn = noc_unified_transaction::type_id::create("noc_read_txn");
        txn.direction  = noc_unified_transaction::NOC_READ;
        txn.addr       = addr;
        txn.size       = size;
        txn.prot       = prot;
        txn.len        = 8'h0;
        txn.burst      = noc_unified_transaction::INCR;
        txn.master_id  = master_id;
        if (slave_name != "") txn.slave_name = slave_name;
        txn.start_time = $realtime;

        ok = execute_txn(txn, timeout_ns);
        data = txn.data;

        if (!ok) begin
            `uvm_warning("NOC_API", $sformatf("noc_read(M%0d->0x%0h) failed resp=%s",
                txn.master_id, addr, txn.resp_name()))
        end
    endtask

    // =====================================================
    // Public API: noc_write
    // =====================================================
    task noc_write(
        input bit [63:0]    addr,
        input bit [1023:0]  data,
        input bit [2:0]     size        = 3'b010,
        input int           master_id   = -1,
        input string        slave_name  = "",
        input bit [127:0]   wstrb       = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        input bit [2:0]     prot        = 3'b000,
        input int           timeout_ns  = 10000
    );
        noc_unified_transaction txn;
        bit ok;

        check_init("noc_write");

        txn = noc_unified_transaction::type_id::create("noc_write_txn");
        txn.direction  = noc_unified_transaction::NOC_WRITE;
        txn.addr       = addr;
        txn.data       = data;
        txn.size       = size;
        txn.wstrb      = wstrb;
        txn.prot       = prot;
        txn.len        = 8'h0;
        txn.burst      = noc_unified_transaction::INCR;
        txn.master_id  = master_id;
        if (slave_name != "") txn.slave_name = slave_name;
        txn.start_time = $realtime;

        ok = execute_txn(txn, timeout_ns);

        if (!ok) begin
            `uvm_warning("NOC_API", $sformatf("noc_write(M%0d->0x%0h) failed resp=%s",
                txn.master_id, addr, txn.resp_name()))
        end
    endtask

    // =====================================================
    // Public API: noc_burst_read
    // =====================================================
    task noc_burst_read(
        input  bit [63:0]                   addr,
        output bit [1023:0]                 data[],
        input  bit [7:0]                    len,
        input  bit [2:0]                    size        = 3'b010,
        input  int                          master_id   = -1,
        input  string                       slave_name  = "",
        input  noc_unified_transaction::burst_type_e burst = noc_unified_transaction::INCR,
        input  bit [2:0]                    prot        = 3'b000,
        input  int                          timeout_ns  = 100000
    );
        noc_unified_transaction txn;
        bit ok;

        check_init("noc_burst_read");

        txn = noc_unified_transaction::type_id::create("noc_burst_read_txn");
        txn.direction  = noc_unified_transaction::NOC_READ;
        txn.addr       = addr;
        txn.size       = size;
        txn.len        = len;
        txn.burst      = burst;
        txn.prot       = prot;
        txn.master_id  = master_id;
        if (slave_name != "") txn.slave_name = slave_name;
        txn.start_time = $realtime;

        ok = execute_txn(txn, timeout_ns);

        data = new[txn.len + 1];
        data[0] = txn.data;

        if (!ok) begin
            `uvm_warning("NOC_API", $sformatf("noc_burst_read(M%0d->0x%0h, len=%0d) failed resp=%s",
                txn.master_id, addr, len, txn.resp_name()))
        end
    endtask

    // =====================================================
    // Public API: noc_burst_write
    // =====================================================
    task noc_burst_write(
        input bit [63:0]                    addr,
        input bit [1023:0]                  data[],
        input bit [7:0]                     len,
        input bit [2:0]                     size        = 3'b010,
        input int                           master_id   = -1,
        input string                        slave_name  = "",
        input bit [127:0]                   wstrb       = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        input noc_unified_transaction::burst_type_e burst = noc_unified_transaction::INCR,
        input bit [2:0]                     prot        = 3'b000,
        input int                           timeout_ns  = 100000
    );
        noc_unified_transaction txn;
        bit ok;

        check_init("noc_burst_write");

        txn = noc_unified_transaction::type_id::create("noc_burst_write_txn");
        txn.direction  = noc_unified_transaction::NOC_WRITE;
        txn.addr       = addr;
        if (data.size() > 0) txn.data = data[0];
        txn.size       = size;
        txn.len        = len;
        txn.wstrb      = wstrb;
        txn.burst      = burst;
        txn.prot       = prot;
        txn.master_id  = master_id;
        if (slave_name != "") txn.slave_name = slave_name;
        txn.start_time = $realtime;

        ok = execute_txn(txn, timeout_ns);

        if (!ok) begin
            `uvm_warning("NOC_API", $sformatf("noc_burst_write(M%0d->0x%0h, len=%0d) failed resp=%s",
                txn.master_id, addr, len, txn.resp_name()))
        end
    endtask

    // =====================================================
    // Backdoor access
    // =====================================================
    task noc_backdoor_read(
        input  bit [63:0]     addr,
        output bit [31:0]     data,
        input  int            bd_type = `NOC_BACKDOOR_MEM
    );
        `uvm_info("NOC_API", $sformatf("Backdoor read: 0x%0h", addr), UVM_MEDIUM)
        data = 32'h0;
    endtask

    task noc_backdoor_write(
        input bit [63:0]     addr,
        input bit [31:0]     data,
        input int            bd_type = `NOC_BACKDOOR_MEM
    );
        `uvm_info("NOC_API", $sformatf("Backdoor write: 0x%0h = 0x%0h", addr, data), UVM_MEDIUM)
    endtask

    // =====================================================
    // Internal helpers
    // =====================================================
    function void check_init(string caller);
        if (!m_initialized) begin
            `uvm_warning("NOC_API", $sformatf("%s: API not initialized.", caller))
        end
    endfunction

    function bit execute_txn(noc_unified_transaction txn, int timeout_ns);
        if (m_vseqr != null) begin
            m_vseqr.execute_single(txn);
            wait(txn.end_time > 0);
            return (txn.resp == noc_unified_transaction::RESP_OKAY);
        end else begin
            #(10ns);
            if (txn.direction == noc_unified_transaction::NOC_READ)
                txn.data = txn.addr;
            txn.resp = noc_unified_transaction::RESP_OKAY;
            txn.end_time = $realtime;
            return 1'b1;
        end
    endfunction
endclass
