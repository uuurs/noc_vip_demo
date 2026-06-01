// noc_axi_checker.sv - AXI4 protocol compliance checker
class noc_axi_checker extends noc_protocol_checker;

    `uvm_component_utils(noc_axi_checker)

    // AXI-specific state tracking
    protected int           m_aw_pending;
    protected int           m_ar_pending;
    protected int           m_w_beat_count[16];
    protected int           m_r_beat_count[16];
    protected int           m_outstanding_wr;
    protected int           m_outstanding_rd;
    protected bit [63:0]    m_active_aw_addr;
    protected bit [63:0]    m_active_ar_addr;
    protected bit [7:0]     m_active_awlen;
    protected bit [7:0]     m_active_arlen;
    protected realtime      m_last_aw_time;
    protected realtime      m_last_ar_time;
    protected realtime      m_last_w_time;
    protected int           m_max_outstanding;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_protocol_name = "AXI4";
        m_aw_pending    = 0;
        m_ar_pending    = 0;
        m_outstanding_wr = 0;
        m_outstanding_rd = 0;
        m_max_outstanding = 16;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (m_cfg != null) begin
            foreach (m_cfg.slaves[i])
                if (m_cfg.slaves[i] != null && m_cfg.slaves[i].outstanding_capability > m_max_outstanding)
                    m_max_outstanding = m_cfg.slaves[i].outstanding_capability;
        end
    endfunction

    virtual function void write(noc_unified_transaction t);
        super.write(t);

        if (t.protocol != noc_unified_transaction::NOC_AXI4) return;

        // Rule AXI-01: 4KB boundary check for bursts
        if (t.len > 0 && t.is_4kb_crossing()) begin
            report_violation("AXI_4KB_BOUNDARY", `NOC_RULE_BOUNDARY,
                $sformatf("Burst crosses 4KB boundary: addr=0x%0h len=%0d size=%0d end=0x%0h",
                    t.addr, t.len, t.size, t.get_end_addr()),
                t.addr, t.master_id, t.slave_id, noc_violation_report::FATAL);
        end

        // Rule AXI-02: Unaligned address for transfer size
        if (t.addr % (2**t.size) != 0) begin
            report_violation("AXI_ALIGNMENT", `NOC_RULE_ALIGNMENT,
                $sformatf("Unaligned addr=0x%0h for size=%0d", t.addr, t.size),
                t.addr, t.master_id, t.slave_id, noc_violation_report::ERROR);
        end

        // Rule AXI-03: Outstanding transaction tracking
        if (t.direction == noc_unified_transaction::NOC_WRITE) begin
            m_outstanding_wr++;
            m_aw_pending = 1;
            m_active_aw_addr = t.addr;
            m_active_awlen = t.len;
            m_last_aw_time = $realtime;
        end else begin
            m_outstanding_rd++;
            m_ar_pending = 1;
            m_active_ar_addr = t.addr;
            m_active_arlen = t.len;
            m_last_ar_time = $realtime;
        end

        // Check outstanding limit
        if ((m_outstanding_wr + m_outstanding_rd) > m_max_outstanding) begin
            report_violation("AXI_OUTSTANDING", `NOC_RULE_ORDERING,
                $sformatf("Outstanding limit %0d exceeded: wr=%0d rd=%0d",
                    m_max_outstanding, m_outstanding_wr, m_outstanding_rd),
                t.addr, t.master_id, t.slave_id, noc_violation_report::WARNING);
        end

        // Rule AXI-04: Response code validity
        if (t.resp == noc_unified_transaction::RESP_OKAY) begin
            m_outstanding_wr = (m_outstanding_wr > 0) ? m_outstanding_wr - 1 : 0;
        end else if (t.resp == noc_unified_transaction::RESP_DECERR) begin
            report_violation("AXI_DECERR", `NOC_RULE_DATA_INTEG,
                $sformatf("DECERR response for addr=0x%0h", t.addr),
                t.addr, t.master_id, t.slave_id, noc_violation_report::ERROR);
        end else if (t.resp == noc_unified_transaction::RESP_SLVERR) begin
            report_violation("AXI_SLVERR", `NOC_RULE_DATA_INTEG,
                $sformatf("SLVERR response for addr=0x%0h", t.addr),
                t.addr, t.master_id, t.slave_id, noc_violation_report::ERROR);
        end

        // Rule AXI-05: Burst length must not exceed protocol limit (256 for AXI4)
        if (t.len > 255) begin
            report_violation("AXI_MAX_LEN", `NOC_RULE_BURST,
                $sformatf("Burst length %0d exceeds AXI4 max of 256", t.len),
                t.addr, t.master_id, t.slave_id, noc_violation_report::FATAL);
        end

        // Rule AXI-06: Wrap burst must have correct alignment
        if (t.burst == noc_unified_transaction::WRAP) begin
            int wrap_size = (t.len + 1) * (2**t.size);
            if (wrap_size > 0 && (t.addr % wrap_size != 0)) begin
                report_violation("AXI_WRAP_ALIGN", `NOC_RULE_BURST,
                    $sformatf("Wrap burst not aligned to burst size: addr=0x%0h wrap_size=%0d",
                        t.addr, wrap_size),
                    t.addr, t.master_id, t.slave_id, noc_violation_report::ERROR);
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("AXI_CHECKER", $sformatf(
            "AXI4 Checker Summary: %0d violations | Max outstanding: wr=%0d rd=%0d",
            m_violation_count, m_outstanding_wr, m_outstanding_rd), UVM_LOW)
    endfunction
endclass
