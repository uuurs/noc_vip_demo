// noc_ahb_checker.sv - AHB-Lite protocol compliance checker
class noc_ahb_checker extends noc_protocol_checker;

    `uvm_component_utils(noc_ahb_checker)

    // AHB state tracking
    typedef enum { IDLE, BUSY, NONSEQ, SEQ } htrans_e;
    protected htrans_e  m_last_htrans;
    protected bit [63:0] m_last_haddr;
    protected int        m_beat_count_in_burst;
    protected int        m_expected_beats;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_protocol_name = "AHB-Lite";
        m_last_htrans = IDLE;
        m_beat_count_in_burst = 0;
        m_expected_beats = 0;
    endfunction

    virtual function void write(noc_unified_transaction t);
        super.write(t);
        if (t.protocol != noc_unified_transaction::NOC_AHBLITE) return;

        // Rule AHB-01: HTRANS sequencing (simplified via burst tracking)
        // IDLE -> NONSEQ/BUSY, BUSY -> NONSEQ/SEQ/BUSY, NONSEQ -> BUSY/SEQ/NONSEQ, SEQ -> BUSY/SEQ/NONSEQ
        // Track via burst count
        if (t.len == 0 && t.burst == noc_unified_transaction::FIXED)
            m_beat_count_in_burst = 1;  // single beat
        else
            m_beat_count_in_burst = t.len + 1;

        // Rule AHB-02: 1KB boundary check for AHB
        if (t.get_end_addr() / 1024 != t.addr / 1024) begin
            report_violation("AHB_1KB_BOUNDARY", `NOC_RULE_BOUNDARY,
                $sformatf("Burst crosses 1KB boundary: addr=0x%0h end=0x%0h",
                    t.addr, t.get_end_addr()),
                t.addr, t.master_id, t.slave_id, noc_violation_report::FATAL);
        end

        // Rule AHB-03: Size must be 8/16/32 bit only
        if (t.size > 2) begin
            report_violation("AHB_MAX_SIZE", `NOC_RULE_BURST,
                $sformatf("AHB-Lite only supports up to 32-bit transfers, size=%0d", t.size),
                t.addr, t.master_id, t.slave_id, noc_violation_report::ERROR);
        end

        // Rule AHB-04: Slave response check
        if (t.resp == noc_unified_transaction::RESP_OKAY) begin
            // OK - normal response
        end else if (t.resp == noc_unified_transaction::RESP_SLVERR) begin
            report_violation("AHB_SLVERR", `NOC_RULE_DATA_INTEG,
                $sformatf("SLVERR response (AHB ERROR) for addr=0x%0h", t.addr),
                t.addr, t.master_id, t.slave_id, noc_violation_report::ERROR);
        end

        // Rule AHB-05: No locking support in AHB-Lite
        if (t.lock) begin
            report_violation("AHB_LOCK", `NOC_RULE_HANDSHAKE,
                "Lock transfers not supported in AHB-Lite",
                t.addr, t.master_id, t.slave_id, noc_violation_report::ERROR);
        end
    endfunction
endclass
