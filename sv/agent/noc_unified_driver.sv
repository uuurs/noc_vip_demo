// noc_unified_driver.sv - Routes unified transactions to protocol adapters
class noc_unified_driver extends uvm_driver #(noc_unified_transaction);

    `uvm_component_utils(noc_unified_driver)

    noc_adapter_base     m_adapters[$];
    noc_env_cfg          m_cfg;
    int                  m_master_id;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(noc_env_cfg)::get(this, "", "noc_env_cfg", m_cfg))
            `uvm_fatal("NOC_DRV", "Failed to get noc_env_cfg from config_db")
    endfunction

    // Register a protocol adapter
    function void register_adapter(noc_adapter_base adapter);
        m_adapters.push_back(adapter);
        `uvm_info(get_name(), $sformatf("Registered adapter: %s", adapter.get_protocol_name()), UVM_MEDIUM)
    endfunction

    // Route transaction by protocol + address
    function noc_adapter_base find_adapter(
        noc_unified_transaction::protocol_e proto, bit [63:0] addr
    );
        // First: match by protocol and address range
        foreach (m_adapters[i]) begin
            if (m_adapters[i].get_protocol() == proto && m_adapters[i].can_serve_addr(addr))
                return m_adapters[i];
        end
        // Second: match by protocol only (fallback)
        foreach (m_adapters[i]) begin
            if (m_adapters[i].get_protocol() == proto)
                return m_adapters[i];
        end
        `uvm_error("NOC_DRV", $sformatf("No adapter found for protocol=%s addr=0x%0h",
            addr, proto.name()))
        return null;
    endfunction

    // Main run phase: drive loop
    task run_phase(uvm_phase phase);
        `uvm_info(get_name(), "Unified driver starting run_phase", UVM_MEDIUM)

        forever begin
            seq_item_port.get_next_item(req);

            noc_adapter_base adapter = find_adapter(req.protocol, req.addr);
            if (adapter == null) begin
                req.resp = noc_unified_transaction::RESP_DECERR;
                seq_item_port.item_done();
                continue;
            end

            // Validate transaction against slave capabilities
            if (!adapter.validate_txn(req)) begin
                req.resp = noc_unified_transaction::RESP_SLVERR;
                seq_item_port.item_done();
                continue;
            end

            req.start_time = $realtime;

            // Convert to protocol-specific transaction
            uvm_sequence_item proto_txn = adapter.create_proto_txn();
            if (proto_txn != null) begin
                adapter.to_protocol_txn(req, proto_txn);
                // Send to SVT sequencer (in actual implementation)
                // uvm_sequencer_base svt_seqr = adapter.get_svt_sequencer();
                // proto_txn.start(svt_seqr);
                adapter.wait_response(proto_txn, req);
            end else begin
                // When SVT VIP is not available, simulate response
                #(m_cfg.clk_period_ps * 1ps * 10);
                if (req.direction == noc_unified_transaction::NOC_READ) begin
                    req.data = req.addr;  // echo address as data for debug
                end
                req.resp = noc_unified_transaction::RESP_OKAY;
            end

            req.end_time = $realtime;
            req.last = 1'b1;
            req.beat_count = req.len + 1;

            seq_item_port.item_done(req);
        end
    endtask
endclass
