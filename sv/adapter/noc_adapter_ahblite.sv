// noc_adapter_ahblite.sv - AHB-Lite protocol adapter wrapping SVT AHB VIP
// SVT VIP classes used:
//   svt_ahb_master_transaction, svt_ahb_transaction
//   svt_ahb_master_agent, svt_ahb_master_sequencer
//   svt_ahb_master_configuration, svt_ahb_slave_configuration
class noc_adapter_ahblite extends noc_adapter_base;

    `uvm_object_utils(noc_adapter_ahblite)

    svt_ahb_master_configuration  m_svt_ahb_cfg;

    function new(string name = "noc_adapter_ahblite");
        super.new(name);
        m_protocol_name = "AHB-Lite";
    endfunction

    virtual function noc_unified_transaction::protocol_e get_protocol();
        return noc_unified_transaction::NOC_AHBLITE;
    endfunction

    virtual function uvm_sequence_item create_proto_txn();
        return svt_ahb_master_transaction::type_id::create("svt_ahb_txn");
    endfunction

    virtual function void to_protocol_txn(
        noc_unified_transaction unified_txn,
        uvm_sequence_item       proto_txn
    );
        svt_ahb_master_transaction ahb_txn;
        if (!$cast(ahb_txn, proto_txn)) begin
            `uvm_fatal("ADAPTER_AHBLITE", "proto_txn is not svt_ahb_master_transaction")
            return;
        end

        // AHB-Lite field mapping
        ahb_txn.addr   = unified_txn.addr;
        ahb_txn.burst  = map_burst_type(unified_txn.burst, unified_txn.len);
        ahb_txn.len    = unified_txn.len;
        ahb_txn.size   = map_burst_size(unified_txn.size);
        ahb_txn.hprot  = {1'b0, unified_txn.prot};  // 4-bit HPROT
        ahb_txn.hwrite = (unified_txn.direction == noc_unified_transaction::NOC_WRITE);

        if (unified_txn.direction == noc_unified_transaction::NOC_WRITE)
            ahb_txn.hwdata = unified_txn.data;
        else
            ahb_txn.data = unified_txn.data;  // for read, use data field

        `uvm_info("ADAPTER_AHBLITE", $sformatf("to_protocol: %s -> AHB addr=0x%0h burst=%0s size=%0d hwrite=%0b",
            unified_txn.convert2string(), ahb_txn.addr, ahb_txn.burst.name(), ahb_txn.size, ahb_txn.hwrite), UVM_HIGH)
    endfunction

    virtual function void from_protocol_txn(
        uvm_sequence_item       proto_txn,
        noc_unified_transaction unified_txn
    );
        svt_ahb_master_transaction ahb_txn;
        if (!$cast(ahb_txn, proto_txn)) begin
            `uvm_fatal("ADAPTER_AHBLITE", "proto_txn is not svt_ahb_master_transaction")
            return;
        end

        unified_txn.data     = ahb_txn.hrdata;
        unified_txn.resp     = (ahb_txn.hresp == 0) ?
            noc_unified_transaction::RESP_OKAY : noc_unified_transaction::RESP_SLVERR;
        unified_txn.end_time = $realtime;

        // AHB response is single-cycle; treat as last
        unified_txn.last = 1'b1;
    endfunction

    virtual function void configure(noc_slave_config slave_cfg, noc_master_config master_cfg);
        super.configure(slave_cfg, master_cfg);
        m_svt_ahb_cfg = svt_ahb_master_configuration::type_id::create("svt_ahb_cfg");
        m_svt_ahb_cfg.addr_width = 32;
        m_svt_ahb_cfg.data_width = 32;
        m_svt_ahb_cfg.is_active  = 1;
    endfunction

    // =====================================================
    // AHB burst type mapping
    // AHB supports: SINGLE, INCR, INCR4, INCR8, INCR16, WRAP4, WRAP8, WRAP16
    // Unified: FIXED->SINGLE, INCR len decides 4/8/16, WRAP len decides 4/8/16
    // =====================================================
    local function svt_ahb_transaction::burst_enum map_burst_type(
        noc_unified_transaction::burst_type_e bt, bit [7:0] len
    );
        if (len == 0) return svt_ahb_transaction::SINGLE;

        case (bt)
            noc_unified_transaction::FIXED: return svt_ahb_transaction::SINGLE;
            noc_unified_transaction::INCR: begin
                if (len < 3)       return svt_ahb_transaction::INCR;
                else if (len < 7)  return svt_ahb_transaction::INCR4;
                else if (len < 15) return svt_ahb_transaction::INCR8;
                else               return svt_ahb_transaction::INCR16;
            end
            noc_unified_transaction::WRAP: begin
                if (len < 3)       return svt_ahb_transaction::WRAP4;
                else if (len < 7)  return svt_ahb_transaction::WRAP4;
                else if (len < 15) return svt_ahb_transaction::WRAP8;
                else               return svt_ahb_transaction::WRAP16;
            end
            default: return svt_ahb_transaction::SINGLE;
        endcase
    endfunction

    local function svt_ahb_transaction::size_enum map_burst_size(bit [2:0] size);
        case (size)
            0: return svt_ahb_transaction::BYTE;       // 8-bit
            1: return svt_ahb_transaction::HALFWORD;   // 16-bit
            2: return svt_ahb_transaction::WORD;       // 32-bit
            default: begin
                `uvm_warning("ADAPTER_AHBLITE", $sformatf("AHB-Lite max size is 32-bit, got size=%0d", size))
                return svt_ahb_transaction::WORD;
            end
        endcase
    endfunction
endclass
