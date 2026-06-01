// noc_adapter_axi4.sv - AXI4 protocol adapter wrapping SVT AXI VIP
// SVT VIP classes used:
//   svt_axi_master_transaction, svt_axi_transaction
//   svt_axi_master_agent, svt_axi_master_sequencer
//   svt_axi_port_configuration, svt_axi_system_configuration
class noc_adapter_axi4 extends noc_adapter_base;

    `uvm_object_utils(noc_adapter_axi4)

    // SVT AXI port configuration handle
    svt_axi_port_configuration   m_svt_axi_cfg;

    function new(string name = "noc_adapter_axi4");
        super.new(name);
        m_protocol_name = "AXI4";
    endfunction

    virtual function noc_unified_transaction::protocol_e get_protocol();
        return noc_unified_transaction::NOC_AXI4;
    endfunction

    // =====================================================
    // Create SVT AXI transaction
    // =====================================================
    virtual function uvm_sequence_item create_proto_txn();
        svt_axi_master_transaction txn;
        txn = svt_axi_master_transaction::type_id::create("svt_axi_txn");
        return txn;
    endfunction

    // =====================================================
    // Unified -> SVT AXI field mapping
    // =====================================================
    virtual function void to_protocol_txn(
        noc_unified_transaction unified_txn,
        uvm_sequence_item       proto_txn
    );
        svt_axi_master_transaction axi_txn;
        if (!$cast(axi_txn, proto_txn)) begin
            `uvm_fatal("ADAPTER_AXI4", "proto_txn is not svt_axi_master_transaction")
            return;
        end

        // Core address/control
        axi_txn.addr         = unified_txn.addr;
        axi_txn.burst_size   = map_burst_size(unified_txn.size);
        axi_txn.burst_length = unified_txn.len;
        axi_txn.burst_type   = map_burst_type(unified_txn.burst);
        axi_txn.id           = unified_txn.id;
        axi_txn.qos          = unified_txn.qos;
        axi_txn.cache_type   = unified_txn.cache;
        axi_txn.prot_type    = unified_txn.prot;
        axi_txn.lock_type    = unified_txn.lock ? svt_axi_transaction::EXCLUSIVE : svt_axi_transaction::NORMAL;
        axi_txn.user         = {unified_txn.user, 32'h0};

        // Data/Strobe
        axi_txn.data         = unified_txn.data;
        axi_txn.atomic_data  = unified_txn.data;
        axi_txn.wstrb        = unified_txn.wstrb;

        // Direction
        if (unified_txn.direction == noc_unified_transaction::NOC_WRITE) begin
            axi_txn.xact_type = svt_axi_transaction::WRITE;
        end else begin
            axi_txn.xact_type = svt_axi_transaction::READ;
        end

        // Slave response setup
        axi_txn.resp         = map_resp_to_svt(unified_txn.resp);

        `uvm_info("ADAPTER_AXI4", $sformatf("to_protocol: %s -> AXI xact=%s addr=0x%0h len=%0d size=%0d id=%0d",
            unified_txn.convert2string(),
            (axi_txn.xact_type == svt_axi_transaction::WRITE) ? "WRITE" : "READ",
            axi_txn.addr, axi_txn.burst_length, axi_txn.burst_size, axi_txn.id), UVM_HIGH)
    endfunction

    // =====================================================
    // SVT AXI -> Unified field mapping (response extraction)
    // =====================================================
    virtual function void from_protocol_txn(
        uvm_sequence_item       proto_txn,
        noc_unified_transaction unified_txn
    );
        svt_axi_master_transaction axi_txn;
        if (!$cast(axi_txn, proto_txn)) begin
            `uvm_fatal("ADAPTER_AXI4", "proto_txn is not svt_axi_master_transaction")
            return;
        end

        unified_txn.data      = axi_txn.data;
        unified_txn.resp      = map_resp_from_svt(axi_txn.resp);
        unified_txn.last      = axi_txn.last;
        unified_txn.id        = axi_txn.id;
        unified_txn.end_time  = $realtime;
    endfunction

    // =====================================================
    // Configuration
    // =====================================================
    virtual function void configure(noc_slave_config slave_cfg, noc_master_config master_cfg);
        super.configure(slave_cfg, master_cfg);

        // Create SVT AXI port configuration
        m_svt_axi_cfg = svt_axi_port_configuration::type_id::create("svt_axi_cfg");
        m_svt_axi_cfg.addr_width             = 64;
        m_svt_axi_cfg.data_width             = 64;
        m_svt_axi_cfg.id_width               = master_cfg.thread_id_width;
        m_svt_axi_cfg.outstanding_xact_depth = slave_cfg.outstanding_capability;
        m_svt_axi_cfg.is_active              = 1;

        `uvm_info("ADAPTER_AXI4", $sformatf("Configured: %s outstanding=%0d id_width=%0d",
            slave_cfg.name, slave_cfg.outstanding_capability, master_cfg.thread_id_width), UVM_MEDIUM)
    endfunction

    // =====================================================
    // Send to SVT sequencer (real SVT integration path)
    // =====================================================
    virtual task send_to_svt(uvm_sequence_item proto_txn);
        svt_axi_master_sequencer axi_seqr;
        svt_axi_master_transaction axi_txn;

        if (!$cast(axi_txn, proto_txn)) begin
            `uvm_fatal("ADAPTER_AXI4", "Cannot cast to svt_axi_master_transaction")
        end

        if ($cast(axi_seqr, m_svt_seqr)) begin
            axi_txn.start(axi_seqr);
        end else begin
            `uvm_warning("ADAPTER_AXI4", "SVT sequencer not connected; using default simulation path")
            super.send_to_svt(proto_txn);
        end
    endtask

    // =====================================================
    // Field mapping helpers
    // =====================================================
    local function svt_axi_transaction::burst_size_enum map_burst_size(bit [2:0] size);
        case (size)
            0: return svt_axi_transaction::BURST_SIZE_8BIT;
            1: return svt_axi_transaction::BURST_SIZE_16BIT;
            2: return svt_axi_transaction::BURST_SIZE_32BIT;
            3: return svt_axi_transaction::BURST_SIZE_64BIT;
            4: return svt_axi_transaction::BURST_SIZE_128BIT;
            5: return svt_axi_transaction::BURST_SIZE_256BIT;
            6: return svt_axi_transaction::BURST_SIZE_512BIT;
            7: return svt_axi_transaction::BURST_SIZE_1024BIT;
            default: return svt_axi_transaction::BURST_SIZE_32BIT;
        endcase
    endfunction

    local function svt_axi_transaction::burst_type_enum map_burst_type(
        noc_unified_transaction::burst_type_e bt
    );
        case (bt)
            noc_unified_transaction::FIXED: return svt_axi_transaction::FIXED;
            noc_unified_transaction::INCR:  return svt_axi_transaction::INCR;
            noc_unified_transaction::WRAP:  return svt_axi_transaction::WRAP;
            default:                        return svt_axi_transaction::INCR;
        endcase
    endfunction

    local function svt_axi_transaction::resp_enum map_resp_to_svt(
        noc_unified_transaction::resp_e r
    );
        case (r)
            noc_unified_transaction::RESP_OKAY:   return svt_axi_transaction::OKAY;
            noc_unified_transaction::RESP_EXOKAY: return svt_axi_transaction::EXOKAY;
            noc_unified_transaction::RESP_SLVERR: return svt_axi_transaction::SLVERR;
            noc_unified_transaction::RESP_DECERR: return svt_axi_transaction::DECERR;
            default:                              return svt_axi_transaction::OKAY;
        endcase
    endfunction

    local function noc_unified_transaction::resp_e map_resp_from_svt(
        svt_axi_transaction::resp_enum r
    );
        case (r)
            svt_axi_transaction::OKAY:   return noc_unified_transaction::RESP_OKAY;
            svt_axi_transaction::EXOKAY: return noc_unified_transaction::RESP_EXOKAY;
            svt_axi_transaction::SLVERR: return noc_unified_transaction::RESP_SLVERR;
            svt_axi_transaction::DECERR: return noc_unified_transaction::RESP_DECERR;
            default:                     return noc_unified_transaction::RESP_OKAY;
        endcase
    endfunction
endclass
