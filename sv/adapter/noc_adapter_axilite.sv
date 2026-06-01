// noc_adapter_axilite.sv - AXI4-Lite protocol adapter
class noc_adapter_axilite extends noc_adapter_base;

    `uvm_object_utils(noc_adapter_axilite)

    function new(string name = "noc_adapter_axilite");
        super.new(name);
        m_protocol_name = "AXI4-Lite";
    endfunction

    virtual function noc_unified_transaction::protocol_e get_protocol();
        return noc_unified_transaction::NOC_AXILITE;
    endfunction

    virtual function void to_protocol_txn(
        noc_unified_transaction unified_txn,
        uvm_sequence_item       proto_txn
    );
        // AXI4-Lite: no burst, len=0, size limited to 1/2 (16/32bit) or 2/3 for 32/64bit
        `uvm_info("ADAPTER_AXILITE", $sformatf("to_protocol: %s", unified_txn.convert2string()), UVM_HIGH)
    endfunction

    virtual function void from_protocol_txn(
        uvm_sequence_item       proto_txn,
        noc_unified_transaction unified_txn
    );
        `uvm_info("ADAPTER_AXILITE", $sformatf("from_protocol: %s", unified_txn.convert2string()), UVM_HIGH)
    endfunction

    virtual function uvm_sequence_item create_proto_txn();
        return null;  // Placeholder for svt_axi_lite_transaction
    endfunction
endclass
