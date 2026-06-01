// noc_protocol_checker.sv - Base protocol checker with violation reporting
class noc_protocol_checker extends uvm_subscriber #(noc_unified_transaction);

    `uvm_component_utils(noc_protocol_checker)

    noc_env_cfg                     m_cfg;
    noc_violation_report            m_violations[$];
    string                          m_protocol_name;
    int                             m_violation_count;
    string                          m_violation_log_file;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_protocol_name = "BASE";
        m_violation_count = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(noc_env_cfg)::get(this, "", "noc_env_cfg", m_cfg))
            `uvm_fatal("NOC_CHECKER", "Failed to get noc_env_cfg from config_db")
        m_violation_log_file = m_cfg.violation_log_path;
    endfunction

    function void report_violation(
        string rule_name, string rule_cat, string detail,
        bit [63:0] addr, int master_id, int slave_id,
        noc_violation_report::severity_e sev = noc_violation_report::ERROR
    );
        noc_violation_report rpt = noc_violation_report::type_id::create();
        rpt.protocol      = m_protocol_name;
        rpt.rule_name     = rule_name;
        rpt.rule_category = rule_cat;
        rpt.detail        = detail;
        rpt.address       = addr;
        rpt.master_id     = master_id;
        rpt.slave_id      = slave_id;
        rpt.timestamp     = $realtime;
        rpt.severity      = sev;
        m_violations.push_back(rpt);
        m_violation_count++;

        case (sev)
            noc_violation_report::WARNING: `uvm_warning("NOC_CHECKER", rpt.convert2string())
            noc_violation_report::ERROR:   `uvm_error("NOC_CHECKER", rpt.convert2string())
            noc_violation_report::FATAL:   `uvm_fatal("NOC_CHECKER", rpt.convert2string())
            default:                        `uvm_info("NOC_CHECKER", rpt.convert2string(), UVM_MEDIUM)
        endcase
    endfunction

    // Base write method - checks basic rules, protocol-specific subclasses extend
    virtual function void write(noc_unified_transaction t);
        if ((t.direction == noc_unified_transaction::NOC_WRITE) && (t.resp != noc_unified_transaction::RESP_OKAY))
            report_violation("WRITE_ERROR", `NOC_RULE_DATA_INTEG,
                $sformatf("Write to 0x%0h returned %s", t.addr, t.resp_name()),
                t.addr, t.master_id, t.slave_id, noc_violation_report::ERROR);
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("NOC_CHECKER", $sformatf("[%s] Total violations: %0d", m_protocol_name, m_violation_count), UVM_LOW)

        // Write violation report to file
        if (m_violations.size() > 0) begin
            int fd = $fopen(m_violation_log_file, "w");
            if (fd) begin
                $fdisplay(fd, "=== NOC Protocol Violation Report ===");
                $fdisplay(fd, "Protocol: %s", m_protocol_name);
                $fdisplay(fd, "Total Violations: %0d\n", m_violation_count);
                foreach (m_violations[i])
                    $fdisplay(fd, "  %0d: %s", i, m_violations[i].convert2string());
                $fclose(fd);
                `uvm_info("NOC_CHECKER", $sformatf("Violation report written to %s", m_violation_log_file), UVM_MEDIUM)
            end
        end
    endfunction
endclass
