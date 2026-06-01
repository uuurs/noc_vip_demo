# NOC Verification Access Library (noc_vip)

## 项目定位
基于 SystemVerilog + UVM + Synopsys SVT VIP 的可复用 NOC 验证库，封装 AXI4/AXI4-Lite/AHB-Lite/APB4/Avalon-MM 五种协议，提供统一访问 API、自动用例生成、协议检查、性能监控、覆盖率模型。

## 项目结构约定
- `sv/` — 所有 SystemVerilog 源码，按功能分层：adapter/ agent/ transaction/ sequence/ virtual_sequencer/ env/ checker/ logger/ coverage/ performance/ error_injection/ backdoor/ api/ test/
- `tb/` — testbench top、testbench package、testlist
- `rtl/` — DUT wrapper / stub RTL（实际 DUT 在外部项目）
- `config/` — JSON/Excel 配置文件
- `scripts/` — Python 脚本（自动用例生成、日志解析、配置管理）
- `sim/` — 仿真脚本（Makefile、vsim.do、waveforms.do、modelsim.ini）
- `logs/` — 仿真日志输出（gitignored）
- `reports/` — 覆盖率/违规报告（gitignored）
- `out/` — 编译产物（gitignored）

## 关键设计决策
1. **Adapter Pattern**: 通过 `noc_adapter_base` 抽象基类隔离 SVT VIP 差异，每个协议实现独立 adapter
2. **Unified Transaction**: `noc_unified_transaction` 协议无关，所有参数通过 constraint override 配置
3. **Virtual Sequencer**: `noc_virtual_sequencer` 协调多 Master 并行流量，API wrapper 自动路由
4. **Config-Driven**: JSON 配置文件描述 NOC 拓扑，Python 脚本自动生成针对性测试
5. **Analysis Pipeline**: Monitor -> Analysis Port -> (Checker | Logger | Coverage | Perf | Scoreboard) 广播架构

## 开发命令
```bash
# 编译
cd sim && make compile

# 运行单个测试
make run TEST=noc_smoke_test

# 运行回归
make regress

# GUI波形
make wave TEST=noc_burst_test

# 覆盖率
make coverage TEST=noc_random_traffic_test

# 生成自动测试
cd scripts && python gen_noc_tests.py --config ../config/noc_slave_config.json --all

# 验证配置
python gen_slave_config.py --validate ../config/noc_slave_config.json
python gen_slave_config.py --summary ../config/noc_slave_config.json

# 日志分析
python parse_logs.py --csv ../logs/noc_txn_log.csv --summary
python parse_logs.py --csv ../logs/noc_txn_log.csv --perf-report
```

## SVT VIP 集成说明
当前框架代码中的 SVT VIP 调用为占位符。实际集成时：
1. 在 `noc_adapter_*.sv` 中的 `create_proto_txn()` 返回 `svt_*_transaction::type_id::create()`
2. 在 `to_protocol_txn()` 和 `from_protocol_txn()` 中完成 unified <-> SVT 字段映射
3. 在 `noc_unified_driver.sv` 中取消注释 `// proto_txn.start(svt_seqr)` 调用
4. 在 `noc_env.sv` 的 `connect_phase` 中 connect SVT agents 到 DUT signals

## Questa Sim 配置
- 安装路径: C:/questasim64_2021.1/win64
- UVM版本: built-in UVM 1.2
- 编译选项: +acc=rnb -sv
- 仿真命令: vsim -c noc_tb_top_opt -do "run -all; quit -f"
