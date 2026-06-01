// noc_adapter_axi4.sv - AXI4 protocol adapter (wraps SVT AXI VIP)
class noc_adapter_axi4 extends noc_adapter_base;

    `uvm_object_utils(noc_adapter_axi4)

    function new(string name = "noc_adapter_axi4");
        super.new(name);
        m_protocol_name = "AXI4";
    endfunction

    virtual function noc_unified_transaction::protocol_e get_protocol();
        return noc_unified_transaction::NOC_AXI4;
    endfunction

    // Convert unified transaction -> SVT AXI transaction
    virtual function void to_protocol_txn(
        noc_unified_transaction unified_txn,
        uvm_sequence_item       proto_txn
    );
        // Mapping to SVT AXI transaction fields
        // svt_axi_transaction *axi_txn;
        // $cast(axi_txn, proto_txn);
        //
        // axi_txn.addr           = unified_txn.addr;
        // axi_txn.burst_type     = map_burst(unified_txn.burst);
        // axi_txn.burst_length   = unified_txn.len;
        // axi_txn.burst_size     = unified_txn.size;
        // axi_txn.id             = unified_txn.id;
        // axi_txn.qos            = unified_txn.qos;
        // axi_txn.cache_type     = unified_txn.cache;
        // axi_txn.prot_type      = unified_txn.prot;
        // axi_txn.lock_type      = unified_txn.lock;
        // axi_txn.user           = unified_txn.user;
        //
        // if (unified_txn.direction == NOC_WRITE) begin
        //     axi_txn.data       = unified_txn.data;
        //     axi_txn.wstrb      = unified_txn.wstrb;
        //     axi_txn.xact_type  = svt_axi_transaction::WRITE;
        // end else begin
        //     axi_txn.xact_type  = svt_axi_transaction::READ;
        // end

        `uvm_info("ADAPTER_AXI4", $sformatf("to_protocol: %s", unified_txn.convert2string()), UVM_HIGH)
    endfunction

    virtual function void from_protocol_txn(
        uvm_sequence_item       proto_txn,
        noc_unified_transaction unified_txn
    );
        // Extract response data from SVT AXI transaction
        // svt_axi_transaction *axi_txn;
        // $cast(axi_txn, proto_txn);
        //
        // unified_txn.data = axi_txn.data;
        // unified_txn.resp = map_resp(axi_txn.resp);
        // unified_txn.last = axi_txn.last;
        // unified_txn.end_time = $realtime;

        `uvm_info("ADAPTER_AXI4", $sformatf("from_protocol: %s", unified_txn.convert2string()), UVM_HIGH)
    endfunction

    virtual function uvm_sequence_item create_proto_txn();
        // In real implementation, returns svt_axi_transaction::type_id::create()
        // For framework: return a placeholder
        `uvm_info("ADAPTER_AXI4", "create_proto_txn: svt_axi_transaction", UVM_HIGH)
        return null;  // Placeholder - replace with svt_axi_transaction::type_id::create()
    endfunction

    virtual function void configure(noc_slave_config slave_cfg, noc_master_config master_cfg);
        super.configure(slave_cfg, master_cfg);
        // AXI4-specific configuration
        `uvm_info("ADAPTER_AXI4", $sformatf("Configured for slave=%s master=%s",
            slave_cfg.name, master_cfg.name), UVM_MEDIUM)
    endfunction
endclass
