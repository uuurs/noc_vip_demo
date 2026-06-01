// noc_unified_monitor.sv - Monitor that observes and broadcasts unified transactions
class noc_unified_monitor extends uvm_monitor;

    `uvm_component_utils(noc_unified_monitor)

    // Analysis port for downstream components (checker, logger, coverage, scoreboard)
    uvm_analysis_port #(noc_unified_transaction) m_ap;

    // Separate ports for specific consumers
    uvm_analysis_port #(noc_unified_transaction) m_ap_checker;
    uvm_analysis_port #(noc_unified_transaction) m_ap_logger;
    uvm_analysis_port #(noc_unified_transaction) m_ap_coverage;
    uvm_analysis_port #(noc_unified_transaction) m_ap_scoreboard;
    uvm_analysis_port #(noc_unified_transaction) m_ap_perf;

    noc_env_cfg  m_cfg;
    int          m_master_id;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_ap          = new("m_ap", this);
        m_ap_checker  = new("m_ap_checker", this);
        m_ap_logger   = new("m_ap_logger", this);
        m_ap_coverage = new("m_ap_coverage", this);
        m_ap_scoreboard = new("m_ap_scoreboard", this);
        m_ap_perf     = new("m_ap_perf", this);

        if (!uvm_config_db #(noc_env_cfg)::get(this, "", "noc_env_cfg", m_cfg))
            `uvm_fatal("NOC_MON", "Failed to get noc_env_cfg from config_db")
    endfunction

    task run_phase(uvm_phase phase);
        `uvm_info(get_name(), "Unified monitor running", UVM_MEDIUM)
    endtask

    // Called by driver (or SVT monitor) to broadcast observed transactions
    function void observe_txn(noc_unified_transaction txn);
        // Broadcast to all consumers
        m_ap.write(txn);
        m_ap_checker.write(txn);
        m_ap_logger.write(txn);
        m_ap_coverage.write(txn);
        m_ap_perf.write(txn);

        `uvm_info(get_name(), $sformatf("Observed: %s", txn.convert2string()), UVM_HIGH)
    endfunction
endclass
