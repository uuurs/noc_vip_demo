// noc_adapter_apb4.sv - APB4 protocol adapter
class noc_adapter_apb4 extends noc_adapter_base;

    `uvm_object_utils(noc_adapter_apb4)

    function new(string name = "noc_adapter_apb4");
        super.new(name);
        m_protocol_name = "APB4";
    endfunction

    virtual function noc_unified_transaction::protocol_e get_protocol();
        return noc_unified_transaction::NOC_APB4;
    endfunction

    virtual function void to_protocol_txn(
        noc_unified_transaction unified_txn,
        uvm_sequence_item       proto_txn
    );
        // APB4 mapping:
        // PADDR    = unified_txn.addr
        // PWRITE   = (direction == NOC_WRITE)
        // PWDATA   = unified_txn.data
        // PSTRB    = unified_txn.wstrb
        // PSEL     = address decode from slave config
        // APB4 is single-beat only: len=0, FIXED burst
        `uvm_info("ADAPTER_APB4", $sformatf("to_protocol: %s", unified_txn.convert2string()), UVM_HIGH)
    endfunction

    virtual function void from_protocol_txn(
        uvm_sequence_item       proto_txn,
        noc_unified_transaction unified_txn
    );
        // Extract PRDATA, PSLVERR
        `uvm_info("ADAPTER_APB4", $sformatf("from_protocol: %s", unified_txn.convert2string()), UVM_HIGH)
    endfunction

    virtual function uvm_sequence_item create_proto_txn();
        return null;  // Placeholder for svt_apb_transaction
    endfunction
endclass
