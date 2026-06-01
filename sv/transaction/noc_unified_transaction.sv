// noc_unified_transaction.sv - Protocol-agnostic unified transaction
`include "noc_macros.svh"

class noc_unified_transaction extends uvm_sequence_item;

    // =====================================================
    // Type Enums
    // =====================================================
    typedef enum bit [2:0] {
        NOC_AXI4       = `NOC_PROTOCOL_AXI4,
        NOC_AXILITE    = `NOC_PROTOCOL_AXILITE,
        NOC_AHBLITE    = `NOC_PROTOCOL_AHBLITE,
        NOC_APB4       = `NOC_PROTOCOL_APB4,
        NOC_AVALON_MM  = `NOC_PROTOCOL_AVALON_MM
    } protocol_e;

    typedef enum bit {
        NOC_READ  = `NOC_DIR_READ,
        NOC_WRITE = `NOC_DIR_WRITE
    } direction_e;

    typedef enum bit [1:0] {
        FIXED = `NOC_BURST_FIXED,
        INCR  = `NOC_BURST_INCR,
        WRAP  = `NOC_BURST_WRAP
    } burst_type_e;

    typedef enum bit [1:0] {
        RESP_OKAY   = `NOC_RESP_OKAY,
        RESP_EXOKAY = `NOC_RESP_EXOKAY,
        RESP_SLVERR = `NOC_RESP_SLVERR,
        RESP_DECERR = `NOC_RESP_DECERR
    } resp_e;

    // =====================================================
    // Core Transaction Fields
    // =====================================================
    rand protocol_e    protocol;
    rand direction_e   direction;
    rand bit [63:0]    addr;
    rand bit [1023:0]  data;
    rand bit [127:0]   wstrb;
    rand burst_type_e  burst;
    rand bit [7:0]     len;
    rand bit [2:0]     size;
    rand bit [15:0]    id;
    rand bit [3:0]     qos;
    rand bit [3:0]     cache;
    rand bit [2:0]     prot;
    rand bit           lock;
    rand bit [31:0]    user;

    // Response fields (driven by monitor)
    rand resp_e        resp;
    rand bit           last;
    bit                is_backdoor;

    // Metadata
    int                master_id;
    int                slave_id;
    string             slave_name;
    realtime           start_time;
    realtime           end_time;
    int                beat_count;
    bit [7:0]          data_bytes[];    // byte array for backdoor mem ops

    // =====================================================
    // Constraints (USER OVERRIDE POINTS)
    // =====================================================
    constraint c_default_valid {
        addr inside {[64'h0 : 64'hFFFF_FFFF]};
        burst inside {FIXED, INCR, WRAP};
        len inside {[0:15]};
        size inside {[0:7]};
        id inside {[0:15]};
    }

    constraint c_alignment {
        (size == 0) -> (addr % 1 == 0);
        (size == 1) -> (addr % 2 == 0);
        (size == 2) -> (addr % 4 == 0);
        (size == 3) -> (addr % 8 == 0);
        (size == 4) -> (addr % 16 == 0);
        (size == 5) -> (addr % 32 == 0);
        (size == 6) -> (addr % 64 == 0);
        (size == 7) -> (addr % 128 == 0);
    }

    constraint c_4kb_boundary {
        (size < 7) -> ((addr / 4096) == ((addr + (2**size) * (len + 1) - 1) / 4096));
    }

    constraint c_wstrb_default {
        (direction == NOC_WRITE) -> (wstrb != 0);
    }

    constraint c_axi_lite_restrict {
        (protocol == NOC_AXILITE) -> {
            len == 0;
            size inside {1, 2};
            burst == INCR;
        }
    }

    constraint c_apb_restrict {
        (protocol == NOC_APB4) -> {
            len == 0;
            burst == FIXED;
        }
    }

    constraint c_ahb_restrict {
        (protocol == NOC_AHBLITE) -> {
            len inside {[0:15]};
            size inside {0, 1, 2};
        }
    }

    constraint c_avalon_restrict {
        (protocol == NOC_AVALON_MM) -> {
            burst inside {INCR, FIXED};
        }
    }

    // =====================================================
    // UVM Automation
    // =====================================================
    `uvm_object_utils_begin(noc_unified_transaction)
        `uvm_field_enum(protocol_e, protocol, UVM_DEFAULT)
        `uvm_field_enum(direction_e, direction, UVM_DEFAULT)
        `uvm_field_int(addr, UVM_DEFAULT)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(wstrb, UVM_DEFAULT)
        `uvm_field_enum(burst_type_e, burst, UVM_DEFAULT)
        `uvm_field_int(len, UVM_DEFAULT)
        `uvm_field_int(size, UVM_DEFAULT)
        `uvm_field_int(id, UVM_DEFAULT)
        `uvm_field_int(qos, UVM_DEFAULT)
        `uvm_field_int(cache, UVM_DEFAULT)
        `uvm_field_int(prot, UVM_DEFAULT)
        `uvm_field_int(lock, UVM_DEFAULT)
        `uvm_field_int(user, UVM_DEFAULT)
        `uvm_field_enum(resp_e, resp, UVM_DEFAULT)
        `uvm_field_int(last, UVM_DEFAULT)
        `uvm_field_int(master_id, UVM_DEFAULT)
        `uvm_field_int(slave_id, UVM_DEFAULT)
        `uvm_field_string(slave_name, UVM_DEFAULT)
        `uvm_field_int(beat_count, UVM_DEFAULT)
    `uvm_object_utils_end

    // =====================================================
    // Constructor
    // =====================================================
    function new(string name = "noc_unified_transaction");
        super.new(name);
        protocol    = NOC_AXI4;
        direction   = NOC_READ;
        addr        = 64'h0;
        data        = 1024'h0;
        wstrb       = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        burst       = INCR;
        len         = 8'h0;
        size        = 3'h2;
        id          = 16'h0;
        qos         = 4'h0;
        cache       = 4'h0;
        prot        = 3'h0;
        lock        = 1'b0;
        user        = 32'h0;
        resp        = RESP_OKAY;
        last        = 1'b0;
        is_backdoor = 1'b0;
        master_id   = 0;
        slave_id    = 0;
        slave_name  = "";
        start_time  = 0;
        end_time    = 0;
        beat_count  = 0;
    endfunction

    // =====================================================
    // Utility Methods
    // =====================================================
    function int get_data_bytes();
        return 2**size;
    endfunction

    function int get_transfer_bytes();
        return (len + 1) * (2**size);
    endfunction

    function bit [63:0] get_aligned_addr();
        return {addr[63:size], {size{1'b0}}};
    endfunction

    function bit [63:0] get_end_addr();
        return addr + get_transfer_bytes() - 1;
    endfunction

    function bit is_4kb_crossing();
        return (addr / 4096) != (get_end_addr() / 4096);
    endfunction

    function realtime get_latency();
        if (end_time > start_time)
            return end_time - start_time;
        return 0;
    endfunction

    function string protocol_name();
        case (protocol)
            NOC_AXI4:      return "AXI4";
            NOC_AXILITE:   return "AXI4-Lite";
            NOC_AHBLITE:   return "AHB-Lite";
            NOC_APB4:      return "APB4";
            NOC_AVALON_MM: return "Avalon-MM";
            default:       return "UNKNOWN";
        endcase
    endfunction

    function string burst_name();
        case (burst)
            FIXED: return "FIXED";
            INCR:  return "INCR";
            WRAP:  return "WRAP";
            default: return "UNKNOWN";
        endcase
    endfunction

    function string resp_name();
        case (resp)
            RESP_OKAY:   return "OKAY";
            RESP_EXOKAY: return "EXOKAY";
            RESP_SLVERR: return "SLVERR";
            RESP_DECERR: return "DECERR";
            default:     return "UNKNOWN";
        endcase
    endfunction

    function noc_unified_transaction clone();
        noc_unified_transaction t = noc_unified_transaction::type_id::create();
        t.copy(this);
        return t;
    endfunction

    virtual function string convert2string();
        return $sformatf(
            "%s %s [M%0d->S%0d(%s)] addr=0x%0h data=0x%0h burst=%s len=%0d size=%0d id=%0d resp=%s latency=%0t",
            protocol_name(), (direction == NOC_READ) ? "RD" : "WR",
            master_id, slave_id, slave_name,
            addr, data, burst_name(), len, size, id, resp_name(), get_latency()
        );
    endfunction
endclass
