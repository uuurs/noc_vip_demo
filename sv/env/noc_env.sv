// noc_env.sv - Top-level NOC verification environment
class noc_env extends uvm_env;

    `uvm_component_utils(noc_env)

    // Master agents
    noc_unified_agent           m_master_agents[`NOC_MAX_MASTERS];

    // Slave agents (for passive monitoring at slave side)
    noc_unified_agent           m_slave_agents[`NOC_MAX_SLAVES];

    // Virtual sequencer
    noc_virtual_sequencer       m_vseqr;

    // Analysis components
    noc_protocol_checker        m_checker;
    noc_txn_logger              m_logger;
    noc_coverage_collector      m_coverage;
    noc_perf_monitor            m_perf_monitor;
    noc_error_injector          m_error_injector;
    noc_scoreboard              m_scoreboard;
    noc_backdoor_access         m_backdoor;

    // Configuration
    noc_env_cfg                 m_cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Get configuration from config_db
        if (!uvm_config_db #(noc_env_cfg)::get(this, "", "noc_env_cfg", m_cfg))
            `uvm_fatal("NOC_ENV", "Failed to get noc_env_cfg from config_db")

        if (!m_cfg.validate())
            `uvm_fatal("NOC_ENV", "Configuration validation failed")

        `uvm_info("NOC_ENV", {"\n", m_cfg.convert2string()}, UVM_LOW)

        // Create master agents
        for (int i = 0; i < m_cfg.num_masters; i++) begin
            uvm_config_db #(int)::set(this, $sformatf("m_master_agent[%0d]*", i), "master_id", i);
            m_master_agents[i] = noc_unified_agent::type_id::create(
                $sformatf("m_master_agent[%0d]", i), this);
        end

        // Create virtual sequencer
        m_vseqr = noc_virtual_sequencer::type_id::create("m_vseqr", this);

        // Create optional components based on config flags
        if (m_cfg.enable_checker)
            m_checker = noc_protocol_checker::type_id::create("m_checker", this);

        if (m_cfg.enable_logger)
            m_logger = noc_txn_logger::type_id::create("m_logger", this);

        if (m_cfg.enable_coverage)
            m_coverage = noc_coverage_collector::type_id::create("m_coverage", this);

        if (m_cfg.enable_perf_monitor)
            m_perf_monitor = noc_perf_monitor::type_id::create("m_perf_monitor", this);

        if (m_cfg.enable_scoreboard)
            m_scoreboard = noc_scoreboard::type_id::create("m_scoreboard", this);

        if (m_cfg.enable_error_injection)
            m_error_injector = noc_error_injector::type_id::create("m_error_injector", this);

        if (m_cfg.enable_backdoor)
            m_backdoor = noc_backdoor_access::type_id::create("m_backdoor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Resolve access matrix (allowed_slave_names -> allowed_slave_ids)
        m_cfg.resolve_access_matrix();

        // Connect virtual sequencer to each agent's sequencer
        for (int i = 0; i < m_cfg.num_masters; i++) begin
            if (m_master_agents[i] != null && m_master_agents[i].get_sequencer() != null)
                m_vseqr.m_master_seqr[i] = m_master_agents[i].get_sequencer();
        end

        // Connect monitor analysis ports to analysis components
        for (int i = 0; i < m_cfg.num_masters; i++) begin
            noc_unified_monitor mon = m_master_agents[i].get_monitor();
            if (mon != null) begin
                if (m_checker != null)
                    mon.m_ap_checker.connect(m_checker.analysis_export);
                if (m_logger != null)
                    mon.m_ap_logger.connect(m_logger.analysis_export);
                if (m_coverage != null)
                    mon.m_ap_coverage.connect(m_coverage.analysis_export);
                if (m_perf_monitor != null)
                    mon.m_ap_perf.connect(m_perf_monitor.analysis_export);
                if (m_scoreboard != null)
                    mon.m_ap_scoreboard.connect(m_scoreboard.analysis_export);
            end
        end

        // Wire API wrapper to virtual sequencer
        noc_api_wrapper::get().set_virtual_sequencer(m_vseqr);

        // Wire driver adapters from config
        for (int i = 0; i < m_cfg.num_masters; i++) begin
            noc_master_config mst = m_cfg.masters[i];
            if (mst != null) begin
                // Protocol adapter will be created based on master protocol
                // and registered with the agent
                noc_adapter_base adapter = create_adapter_by_name(mst.protocol);
                if (adapter != null) begin
                    adapter.configure(m_cfg.slaves[0], mst);  // will be refined per slave
                    m_master_agents[i].register_adapter(adapter);
                end
            end
        end
    endfunction

    function noc_adapter_base create_adapter_by_name(string protocol);
        case (protocol)
            "AXI4":      return noc_adapter_axi4::type_id::create();
            "AXI4-Lite": return noc_adapter_axilite::type_id::create();
            "AHB-Lite":  return noc_adapter_ahblite::type_id::create();
            "APB4":      return noc_adapter_apb4::type_id::create();
            "Avalon-MM": return noc_adapter_avalon_mm::type_id::create();
            default: begin
                `uvm_error("NOC_ENV", $sformatf("Unknown protocol: %s", protocol))
                return null;
            end
        endcase
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        `uvm_info("NOC_ENV", "NOC Environment elaboration complete", UVM_LOW)
        `uvm_info("NOC_ENV", $sformatf("Masters:%0d Slaves:%0d Checker:%0s Logger:%0s Coverage:%0s Perf:%0s",
            m_cfg.num_masters, m_cfg.num_slaves,
            m_cfg.enable_checker ? "ON" : "OFF",
            m_cfg.enable_logger ? "ON" : "OFF",
            m_cfg.enable_coverage ? "ON" : "OFF",
            m_cfg.enable_perf_monitor ? "ON" : "OFF"), UVM_MEDIUM)
    endfunction
endclass
