// noc_txn_record.sv - Lightweight transaction record for logging
class noc_txn_record extends uvm_object;

    realtime     timestamp;
    int          master_id;
    int          slave_id;
    string       slave_name;
    bit [63:0]   addr;
    bit [1023:0] data;
    bit [1:0]    resp;
    realtime     latency;
    string       direction;
    string       protocol;
    string       burst_type;
    int          len;
    int          size;
    int          id;
    int          beat_count;
    int          cycle;

    `uvm_object_utils(noc_txn_record)

    function new(string name = "noc_txn_record");
        super.new(name);
        timestamp  = 0;
        master_id  = 0;
        slave_id   = 0;
        slave_name = "";
        addr       = 64'h0;
        data       = 1024'h0;
        resp       = 0;
        latency    = 0;
        direction  = "";
        protocol   = "";
        burst_type = "";
        len        = 0;
        size       = 0;
        id         = 0;
    endfunction

    static function noc_txn_record from_txn(noc_unified_transaction t);
        noc_txn_record r = noc_txn_record::type_id::create();
        r.timestamp  = t.start_time;
        r.master_id  = t.master_id;
        r.slave_id   = t.slave_id;
        r.slave_name = t.slave_name;
        r.addr       = t.addr;
        r.data       = t.data;
        r.resp       = t.resp;
        r.latency    = t.get_latency();
        r.direction  = (t.direction == noc_unified_transaction::NOC_READ) ? "READ" : "WRITE";
        r.protocol   = t.protocol_name();
        r.burst_type = t.burst_name();
        r.len        = t.len;
        r.size       = t.size;
        r.id         = t.id;
        r.beat_count = t.beat_count;
        return r;
    endfunction

    function string to_csv();
        return $sformatf("%0t,%0d,%0d,%s,0x%0h,0x%0h,%s,%0t,%s,%s,%s,%0d,%0d,%0d",
            timestamp, master_id, slave_id, slave_name, addr, data,
            resp_name(), latency, direction, protocol, burst_type, len, size, id);
    endfunction

    static function string csv_header();
        return "timestamp,master,slave,slave_name,addr,data,resp,latency,direction,protocol,burst,len,size,id";
    endfunction

    function string to_json();
        return $sformatf(
            "{\"timestamp\":%0t,\"master\":%0d,\"slave\":%0d,\"slave_name\":\"%s\",\"addr\":\"0x%0h\",\"data\":\"0x%0h\",\"resp\":\"%s\",\"latency\":%0t,\"direction\":\"%s\",\"protocol\":\"%s\",\"burst\":\"%s\",\"len\":%0d,\"size\":%0d,\"id\":%0d}",
            timestamp, master_id, slave_id, slave_name, addr, data,
            resp_name(), latency, direction, protocol, burst_type, len, size, id);
    endfunction

    function string resp_name();
        case (resp)
            0: return "OKAY";
            1: return "EXOKAY";
            2: return "SLVERR";
            3: return "DECERR";
            default: return "UNKNOWN";
        endcase
    endfunction
endclass
