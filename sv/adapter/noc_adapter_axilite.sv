// noc_adapter_axilite.sv - AXI4-Lite protocol adapter wrapping SVT AXI VIP (lite subset)
// SVT VIP classes used:
//   svt_axi_master_transaction (lite mode)
//   svt_axi_port_configuration (lite mode)
class noc_adapter_axilite extends noc_adapter_base;

    `uvm_object_utils(noc_adapter_axilite)

    svt_axi_port_configuration   m_svt_axi_cfg;

    function new(string name = "noc_adapter_axilite");
        super.new(name);
        m_protocol_name = "AXI4-Lite";
    endfunction

    virtual function noc_unified_transaction::protocol_e get_protocol();
        return noc_unified_transaction::NOC_AXILITE;
    endfunction

    virtual function uvm_sequence_item create_proto_txn();
        return svt_axi_master_transaction::type_id::create("svt_axi_lite_txn");
    endfunction

    virtual function void to_protocol_txn(
        noc_unified_transaction unified_txn,
        uvm_sequence_item       proto_txn
    );
        svt_axi_master_transaction axi_txn;
        if (!$cast(axi_txn, proto_txn)) begin
            `uvm_fatal("ADAPTER_AXILITE", "proto_txn is not svt_axi_master_transaction")
            return;
        end

        // AXI4-Lite: single-beat only, no burst
        axi_txn.addr          = unified_txn.addr;
        axi_txn.burst_length  = 0;    // lite: single beat
        axi_txn.burst_type    = svt_axi_transaction::INCR;
        axi_txn.burst_size    = (unified_txn.size <= 2) ?
            ((unified_txn.size == 1) ? svt_axi_transaction::BURST_SIZE_16BIT :
             svt_axi_transaction::BURST_SIZE_32BIT) : svt_axi_transaction::BURST_SIZE_32BIT;
        axi_txn.prot_type     = unified_txn.prot;
        axi_txn.cache_type    = 4'h0;
        axi_txn.lock_type     = svt_axi_transaction::NORMAL;

        if (unified_txn.direction == noc_unified_transaction::NOC_WRITE) begin
            axi_txn.xact_type = svt_axi_transaction::WRITE;
            axi_txn.data      = unified_txn.data;
            axi_txn.wstrb     = unified_txn.wstrb;
        end else begin
            axi_txn.xact_type = svt_axi_transaction::READ;
        end

        `uvm_info("ADAPTER_AXILITE", $sformatf("to_protocol: %s", unified_txn.convert2string()), UVM_HIGH)
    endfunction

    virtual function void from_protocol_txn(
        uvm_sequence_item       proto_txn,
        noc_unified_transaction unified_txn
    );
        svt_axi_master_transaction axi_txn;
        if (!$cast(axi_txn, proto_txn)) begin
            `uvm_fatal("ADAPTER_AXILITE", "proto_txn is not svt_axi_master_transaction")
            return;
        end
        unified_txn.data     = axi_txn.data;
        unified_txn.resp     = (axi_txn.resp == svt_axi_transaction::SLVERR) ?
            noc_unified_transaction::RESP_SLVERR : noc_unified_transaction::RESP_OKAY;
        unified_txn.end_time = $realtime;
    endfunction

    virtual function void configure(noc_slave_config slave_cfg, noc_master_config master_cfg);
        super.configure(slave_cfg, master_cfg);
        m_svt_axi_cfg = svt_axi_port_configuration::type_id::create("svt_axi_lite_cfg");
        m_svt_axi_cfg.is_active = 1;
        m_svt_axi_cfg.addr_width = 64;
        m_svt_axi_cfg.data_width = 32;
        m_svt_axi_cfg.outstanding_xact_depth = 1;  // lite: minimal outstanding
    endfunction
endclass
