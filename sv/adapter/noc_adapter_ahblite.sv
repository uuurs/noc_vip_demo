// noc_adapter_ahblite.sv - AHB-Lite protocol adapter
class noc_adapter_ahblite extends noc_adapter_base;

    `uvm_object_utils(noc_adapter_ahblite)

    function new(string name = "noc_adapter_ahblite");
        super.new(name);
        m_protocol_name = "AHB-Lite";
    endfunction

    virtual function noc_unified_transaction::protocol_e get_protocol();
        return noc_unified_transaction::NOC_AHBLITE;
    endfunction

    virtual function void to_protocol_txn(
        noc_unified_transaction unified_txn,
        uvm_sequence_item       proto_txn
    );
        // AHB-Lite mapping:
        // HADDR    = unified_txn.addr
        // HTRANS   = (first beat) NONSEQ, (subsequent) SEQ
        // HBURST   = map burst type (SINGLE/INCR/INCR4/WRAP4/INCR8/WRAP8/INCR16/WRAP16)
        // HSIZE    = unified_txn.size (limited to 0/1/2 for 8/16/32 bit)
        // HWRITE   = (direction == NOC_WRITE)
        // HWDATA   = unified_txn.data
        // HPROT    = unified_txn.prot
        `uvm_info("ADAPTER_AHBLITE", $sformatf("to_protocol: %s", unified_txn.convert2string()), UVM_HIGH)
    endfunction

    virtual function void from_protocol_txn(
        uvm_sequence_item       proto_txn,
        noc_unified_transaction unified_txn
    );
        // Extract HRDATA, HRESP
        `uvm_info("ADAPTER_AHBLITE", $sformatf("from_protocol: %s", unified_txn.convert2string()), UVM_HIGH)
    endfunction

    virtual function uvm_sequence_item create_proto_txn();
        return null;  // Placeholder for svt_ahb_transaction
    endfunction
endclass
