// noc_apb_checker.sv - APB4 protocol compliance checker
class noc_apb_checker extends noc_protocol_checker;

    `uvm_component_utils(noc_apb_checker)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_protocol_name = "APB4";
    endfunction

    virtual function void write(noc_unified_transaction t);
        super.write(t);
        if (t.protocol != noc_unified_transaction::NOC_APB4) return;

        // Rule APB-01: No burst support in APB
        if (t.len > 0) begin
            report_violation("APB_NO_BURST", `NOC_RULE_BURST,
                $sformatf("APB4 does not support burst, len=%0d", t.len),
                t.addr, t.master_id, t.slave_id, noc_violation_report::ERROR);
        end

        // Rule APB-02: Burst type must be FIXED (single transfer)
        if (t.burst != noc_unified_transaction::FIXED) begin
            report_violation("APB_NO_INCR_WRAP", `NOC_RULE_BURST,
                "APB4 only supports single (FIXED) transfers",
                t.addr, t.master_id, t.slave_id, noc_violation_report::WARNING);
        end

        // Rule APB-03: Write strobe check - APB supports PSTRB
        if (t.direction == noc_unified_transaction::NOC_WRITE && t.wstrb == 0) begin
            report_violation("APB_WSTRB", `NOC_RULE_DATA_INTEG,
                "Write strobe is zero - no bytes enabled",
                t.addr, t.master_id, t.slave_id, noc_violation_report::WARNING);
        end

        // Rule APB-04: Response check
        if (t.resp == noc_unified_transaction::RESP_SLVERR) begin
            report_violation("APB_PSLVERR", `NOC_RULE_DATA_INTEG,
                $sformatf("PSLVERR for addr=0x%0h (APB slave error)", t.addr),
                t.addr, t.master_id, t.slave_id, noc_violation_report::ERROR);
        end
    endfunction
endclass
