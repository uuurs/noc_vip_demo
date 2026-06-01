// noc_unified_agent.sv - Protocol-agnostic unified agent
class noc_unified_agent extends uvm_agent;

    `uvm_component_utils(noc_unified_agent)

    noc_unified_sequencer  m_seqr;
    noc_unified_driver     m_drv;
    noc_unified_monitor    m_mon;

    noc_env_cfg            m_cfg;
    int                    m_master_id;
    string                 m_master_name;
    bit                    m_is_active;

    // Registered protocol adapters
    noc_adapter_base       m_adapters[$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(noc_env_cfg)::get(this, "", "noc_env_cfg", m_cfg))
            `uvm_fatal("NOC_AGT", "Failed to get noc_env_cfg from config_db")
        if (!uvm_config_db #(int)::get(this, "", "master_id", m_master_id))
            m_master_id = 0;

        m_mon = noc_unified_monitor::type_id::create("m_mon", this);

        m_is_active = uvm_config_db #(bit)::get(this, "", "is_active", m_is_active) ?
                      m_is_active : 1'b1;

        if (m_is_active) begin
            m_seqr = noc_unified_sequencer::type_id::create("m_seqr", this);
            m_drv  = noc_unified_driver::type_id::create("m_drv", this);
            m_drv.m_master_id = m_master_id;
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (m_is_active) begin
            m_drv.seq_item_port.connect(m_seqr.seq_item_export);
            // Register all adapters with driver
            foreach (m_adapters[i])
                m_drv.register_adapter(m_adapters[i]);
        end
    endfunction

    function void register_adapter(noc_adapter_base adapter);
        m_adapters.push_back(adapter);
        `uvm_info(get_name(), $sformatf("Agent registered adapter: %s", adapter.get_protocol_name()), UVM_MEDIUM)
    endfunction

    function noc_unified_sequencer get_sequencer();
        return m_seqr;
    endfunction

    function noc_unified_monitor get_monitor();
        return m_mon;
    endfunction
endclass
