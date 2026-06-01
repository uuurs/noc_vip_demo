// noc_adapter_avalon_mm.sv - Avalon-MM protocol adapter
// Note: SVT does not provide a native Avalon-MM VIP.
// This adapter implements a bridge to Avalon-MM via a generic SVT-like transaction model.
// The Avalon-MM protocol fields map to a custom svt_avalon_mm_transaction (user-defined).
// In practice, substitute with: Intel Avalon-MM BFM, or a custom UVM agent.
class noc_adapter_avalon_mm extends noc_adapter_base;

    `uvm_object_utils(noc_adapter_avalon_mm)

    function new(string name = "noc_adapter_avalon_mm");
        super.new(name);
        m_protocol_name = "Avalon-MM";
    endfunction

    virtual function noc_unified_transaction::protocol_e get_protocol();
        return noc_unified_transaction::NOC_AVALON_MM;
    endfunction

    virtual function uvm_sequence_item create_proto_txn();
        // In actual integration, instantiate the Avalon-MM BFM transaction here.
        // Intel provides: avalon_mm_pkg::avalon_mm_transaction
        // Or use a custom: svt_avalon_mm_transaction defined by the user.
        //
        // For now return null — the unified driver has a fallback path when proto_txn is null.
        `uvm_info("ADAPTER_AVALON_MM", "Avalon-MM adapter: using generic transaction path. "
            "Replace with Intel Avalon-MM BFM or custom SVT-like agent for production.", UVM_MEDIUM)
        return null;
    endfunction

    virtual function void to_protocol_txn(
        noc_unified_transaction unified_txn,
        uvm_sequence_item       proto_txn
    );
        // Avalon-MM field mapping (generic path):
        //   address        = unified_txn.addr
        //   burstcount     = unified_txn.len + 1
        //   byteenable     = unified_txn.wstrb (byte-granularity)
        //   read / write   = unified_txn.direction
        //   writedata      = unified_txn.data
        //   readdata       = response data
        //   waitrequest    = backpressure
        //   readdatavalid  = read response valid
        //
        // Avalon-MM burst type is always incrementing (INCR).
        // No wrap or fixed burst support in native Avalon-MM.

        `uvm_info("ADAPTER_AVALON_MM", $sformatf("to_protocol: %s -> Avalon-MM addr=0x%0h burst=%0d",
            unified_txn.convert2string(), unified_txn.addr, unified_txn.len + 1), UVM_HIGH)
    endfunction

    virtual function void from_protocol_txn(
        uvm_sequence_item       proto_txn,
        noc_unified_transaction unified_txn
    );
        // Extract readdata, response from Avalon-MM response
        unified_txn.resp     = noc_unified_transaction::RESP_OKAY;
        unified_txn.last     = 1'b1;
        unified_txn.end_time = $realtime;
        `uvm_info("ADAPTER_AVALON_MM", $sformatf("from_protocol: %s", unified_txn.convert2string()), UVM_HIGH)
    endfunction

    virtual function void configure(noc_slave_config slave_cfg, noc_master_config master_cfg);
        super.configure(slave_cfg, master_cfg);
        // For Avalon-MM: configure byte enable width = data_width / 8, burst count width, etc.
        `uvm_info("ADAPTER_AVALON_MM", $sformatf("Configured: slave=%s master=%s", slave_cfg.name, master_cfg.name), UVM_MEDIUM)
    endfunction
endclass
