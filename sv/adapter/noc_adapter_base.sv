// noc_adapter_base.sv - Abstract adapter base class for protocol wrappers
virtual class noc_adapter_base extends uvm_object;

    // Handle to the underlying SVT VIP agent/sequencer
    protected uvm_sequencer_base   m_svt_seqr;
    protected uvm_component        m_svt_agent;
    protected string               m_protocol_name;
    protected noc_slave_config     m_slave_cfg;
    protected noc_master_config    m_master_cfg;
    protected bit                  m_configured;

    `uvm_object_utils(noc_adapter_base)

    function new(string name = "noc_adapter_base");
        super.new(name);
        m_protocol_name = "BASE";
        m_configured     = 1'b0;
    endfunction

    // =====================================================
    // Pure Virtual Interface
    // =====================================================
    pure virtual function void to_protocol_txn(
        noc_unified_transaction unified_txn,
        uvm_sequence_item       proto_txn
    );

    pure virtual function void from_protocol_txn(
        uvm_sequence_item       proto_txn,
        noc_unified_transaction unified_txn
    );

    pure virtual function noc_unified_transaction::protocol_e get_protocol();

    // =====================================================
    // Virtual Methods (can be overridden)
    // =====================================================
    virtual function void configure(noc_slave_config slave_cfg, noc_master_config master_cfg);
        m_slave_cfg  = slave_cfg;
        m_master_cfg = master_cfg;
        m_configured = 1'b1;
    endfunction

    virtual function uvm_sequence_item create_proto_txn();
        `uvm_fatal("NOC_ADAPTER", "create_proto_txn() must be overridden by protocol adapter")
        return null;
    endfunction

    virtual function uvm_sequencer_base get_svt_sequencer();
        return m_svt_seqr;
    endfunction

    virtual function uvm_component get_svt_agent();
        return m_svt_agent;
    endfunction

    virtual function void set_svt_sequencer(uvm_sequencer_base seqr);
        m_svt_seqr = seqr;
    endfunction

    virtual function void set_svt_agent(uvm_component agent);
        m_svt_agent = agent;
    endfunction

    virtual function string get_protocol_name();
        return m_protocol_name;
    endfunction

    virtual function bit is_configured();
        return m_configured;
    endfunction

    // Default send: just start item on SVT sequencer
    virtual task send_to_svt(uvm_sequence_item proto_txn);
        if (m_svt_seqr == null)
            `uvm_fatal("NOC_ADAPTER", $sformatf("[%s] SVT sequencer not set", m_protocol_name))
        // In actual SVT VIP integration, this uses svt_sequence::start()
        // For framework purposes, we provide the hook
        `uvm_info("NOC_ADAPTER", $sformatf("[%s] Sending to SVT: %s", m_protocol_name, proto_txn.convert2string()), UVM_HIGH)
    endtask

    virtual task wait_response(uvm_sequence_item proto_txn, output noc_unified_transaction unified_txn);
        // Default: convert back after SVT transaction completes
        // Protocol-specific adapters override for response handling
        from_protocol_txn(proto_txn, unified_txn);
    endtask

    // Check if this adapter can serve a given address
    virtual function bit can_serve_addr(bit [63:0] addr);
        if (m_slave_cfg != null)
            return m_slave_cfg.is_in_range(addr);
        return 1'b0;
    endfunction

    // Validate unified transaction constraints for this protocol
    virtual function bit validate_txn(noc_unified_transaction txn);
        if (txn.len > m_slave_cfg.max_len) begin
            `uvm_error("NOC_ADAPTER", $sformatf("[%s] len=%0d exceeds max_len=%0d",
                m_protocol_name, txn.len, m_slave_cfg.max_len))
            return 1'b0;
        end
        if (txn.size > m_slave_cfg.max_size) begin
            `uvm_error("NOC_ADAPTER", $sformatf("[%s] size=%0d exceeds max_size=%0d",
                m_protocol_name, txn.size, m_slave_cfg.max_size))
            return 1'b0;
        end
        return 1'b1;
    endfunction
endclass
