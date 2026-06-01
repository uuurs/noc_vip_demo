// noc_adapter_avalon_mm.sv - Avalon-MM protocol adapter
class noc_adapter_avalon_mm extends noc_adapter_base;

    `uvm_object_utils(noc_adapter_avalon_mm)

    function new(string name = "noc_adapter_avalon_mm");
        super.new(name);
        m_protocol_name = "Avalon-MM";
    endfunction

    virtual function noc_unified_transaction::protocol_e get_protocol();
        return noc_unified_transaction::NOC_AVALON_MM;
    endfunction

    virtual function void to_protocol_txn(
        noc_unified_transaction unified_txn,
        uvm_sequence_item       proto_txn
    );
        // Avalon-MM mapping:
        // address       = unified_txn.addr
        // burstcount    = unified_txn.len + 1
        // byteenable    = unified_txn.wstrb
        // read/write    = unified_txn.direction
        // writedata     = unified_txn.data
        // Avalon-MM uses INCR-like bursting by default (burstcount register)
        `uvm_info("ADAPTER_AVALON_MM", $sformatf("to_protocol: %s", unified_txn.convert2string()), UVM_HIGH)
    endfunction

    virtual function void from_protocol_txn(
        uvm_sequence_item       proto_txn,
        noc_unified_transaction unified_txn
    );
        // Extract readdata, response
        `uvm_info("ADAPTER_AVALON_MM", $sformatf("from_protocol: %s", unified_txn.convert2string()), UVM_HIGH)
    endfunction

    virtual function uvm_sequence_item create_proto_txn();
        return null;  // Placeholder for svt_avalon_mm_transaction
    endfunction
endclass
