// noc_adapter_apb4.sv - APB4 protocol adapter wrapping SVT APB VIP
// SVT VIP classes used:
//   svt_apb_master_transaction, svt_apb_transaction
//   svt_apb_master_agent, svt_apb_master_sequencer
//   svt_apb_slave_configuration, svt_apb_system_configuration
class noc_adapter_apb4 extends noc_adapter_base;

    `uvm_object_utils(noc_adapter_apb4)

    svt_apb_slave_configuration  m_svt_apb_cfg;

    function new(string name = "noc_adapter_apb4");
        super.new(name);
        m_protocol_name = "APB4";
    endfunction

    virtual function noc_unified_transaction::protocol_e get_protocol();
        return noc_unified_transaction::NOC_APB4;
    endfunction

    virtual function uvm_sequence_item create_proto_txn();
        return svt_apb_master_transaction::type_id::create("svt_apb_txn");
    endfunction

    virtual function void to_protocol_txn(
        noc_unified_transaction unified_txn,
        uvm_sequence_item       proto_txn
    );
        svt_apb_master_transaction apb_txn;
        if (!$cast(apb_txn, proto_txn)) begin
            `uvm_fatal("ADAPTER_APB4", "proto_txn is not svt_apb_master_transaction")
            return;
        end

        // APB4 field mapping — single transfer only (no burst)
        apb_txn.addr   = unified_txn.addr;
        apb_txn.data   = unified_txn.data;
        apb_txn.size   = (unified_txn.size <= 2) ? unified_txn.size : 2;
        apb_txn.prot   = unified_txn.prot;
        apb_txn.pstrb  = unified_txn.wstrb[3:0];  // APB max 32-bit, low 4 strobe bits
        apb_txn.write  = (unified_txn.direction == noc_unified_transaction::NOC_WRITE);

        `uvm_info("ADAPTER_APB4", $sformatf("to_protocol: %s -> APB addr=0x%0h write=%0b pstrb=0x%0h",
            unified_txn.convert2string(), apb_txn.addr, apb_txn.write, apb_txn.pstrb), UVM_HIGH)
    endfunction

    virtual function void from_protocol_txn(
        uvm_sequence_item       proto_txn,
        noc_unified_transaction unified_txn
    );
        svt_apb_master_transaction apb_txn;
        if (!$cast(apb_txn, proto_txn)) begin
            `uvm_fatal("ADAPTER_APB4", "proto_txn is not svt_apb_master_transaction")
            return;
        end

        unified_txn.data     = {992'h0, apb_txn.data};
        unified_txn.resp     = apb_txn.pslverr ?
            noc_unified_transaction::RESP_SLVERR : noc_unified_transaction::RESP_OKAY;
        unified_txn.last     = 1'b1;
        unified_txn.end_time = $realtime;
    endfunction

    virtual function void configure(noc_slave_config slave_cfg, noc_master_config master_cfg);
        super.configure(slave_cfg, master_cfg);
        m_svt_apb_cfg = svt_apb_slave_configuration::type_id::create("svt_apb_cfg");
        m_svt_apb_cfg.addr_width = 32;
        m_svt_apb_cfg.is_active  = 1;
    endfunction
endclass
