// noc_scoreboard.sv - Scoreboard for transaction checking
class noc_scoreboard extends uvm_subscriber #(noc_unified_transaction);

    `uvm_component_utils(noc_scoreboard)

    noc_env_cfg         m_cfg;

    // Expected transactions queue (for write-data / read-data matching)
    noc_unified_transaction m_expected_writes[$];

    // Memory model for self-checking
    bit [7:0]           m_mem_model[bit [63:0]];

    // Statistics
    int                 m_total_txns;
    int                 m_passed;
    int                 m_failed;
    int                 m_read_matches;
    int                 m_read_mismatches;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_total_txns      = 0;
        m_passed          = 0;
        m_failed          = 0;
        m_read_matches    = 0;
        m_read_mismatches = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(noc_env_cfg)::get(this, "", "noc_env_cfg", m_cfg))
            `uvm_fatal("NOC_SCB", "Failed to get noc_env_cfg from config_db")
    endfunction

    virtual function void write(noc_unified_transaction t);
        m_total_txns++;

        if (t.direction == noc_unified_transaction::NOC_WRITE) begin
            // Record write to memory model (byte-by-byte for burst)
            bit [63:0] base = t.addr;
            for (int i = 0; i <= t.len; i++) begin
                bit [63:0] byte_addr = base + (i * (2**t.size));
                for (int b = 0; b < (2**t.size); b++) begin
                    if (t.wstrb[b]) begin
                        m_mem_model[byte_addr + b] = t.data[(b*8)+:8];
                    end
                end
            end
            if (t.resp == noc_unified_transaction::RESP_OKAY)
                m_passed++;
            else
                m_failed++;
        end else begin
            // Read: compare with memory model
            bit [63:0]    base      = t.addr;
            bit [1023:0]  expected  = 0;
            bit            mismatch  = 0;

            for (int i = 0; i <= t.len; i++) begin
                bit [63:0] byte_addr = base + (i * (2**t.size));
                for (int b = 0; b < (2**t.size); b++) begin
                    bit [7:0] exp_byte;
                    if (m_mem_model.exists(byte_addr + b))
                        exp_byte = m_mem_model[byte_addr + b];
                    else
                        exp_byte = 8'hXX;
                    expected[(i * (2**t.size) + b) * 8 +: 8] = exp_byte;
                    if (exp_byte !== t.data[(i * (2**t.size) + b) * 8 +: 8])
                        mismatch = 1;
                end
            end

            if (mismatch && t.resp == noc_unified_transaction::RESP_OKAY) begin
                m_read_mismatches++;
                m_failed++;
                `uvm_error("NOC_SCB", $sformatf(
                    "Read mismatch! addr=0x%0h len=%0d\n  Expected: 0x%0h\n  Got:      0x%0h",
                    t.addr, t.len, expected, t.data))
            end else begin
                m_read_matches++;
                m_passed++;
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("NOC_SCB", "\n=== Scoreboard Report ===", UVM_LOW)
        `uvm_info("NOC_SCB", $sformatf("Total: %0d  Passed: %0d  Failed: %0d", m_total_txns, m_passed, m_failed), UVM_LOW)
        `uvm_info("NOC_SCB", $sformatf("Read Matches: %0d  Mismatches: %0d", m_read_matches, m_read_mismatches), UVM_LOW)
        `uvm_info("NOC_SCB", "========================\n", UVM_LOW)
    endfunction
endclass
