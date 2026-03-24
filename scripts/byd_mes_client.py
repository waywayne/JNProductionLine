#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BYD MES 系统客户端
用于与 BYD MES 系统进行通讯
"""

import json
import sys
import requests
import time
import configparser
from datetime import datetime

def log_message(message, log_file=None):
    """打印并记录日志"""
    print(message, file=sys.stderr, flush=True)
    if log_file:
        with open(log_file, "a", encoding='utf-8') as f:
            current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            f.write(f"{current_time}: {message}\n")

def get_sfc_info(mes_ip, client_id, sn, log_file=None):
    """获取 SFC 信息"""
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36",
        "Cookie": "cookiesession1=426EF394ULRHIHCOMFONBBXJAGLM1F47;"
    }
    
    url = f'http://{mes_ip}/Service.action?method=GetSfcInfo&param={{"LOGIN_ID":"-1","CLIENT_ID":"{client_id}","SFC":"{sn}"}}'
    
    log_message(f"[MES] 获取 SFC 信息: {sn}", log_file)
    log_message(f"[MES] URL: {url}", log_file)
    
    retry_count = 0
    max_retries = 3
    
    while retry_count < max_retries:
        try:
            response = requests.get(url=url, headers=headers, timeout=5)
            data = json.loads(response.text)
            
            log_message(f"[MES] 响应: {json.dumps(data, ensure_ascii=False)}", log_file)
            
            if data['RESULT'] == 'FAIL':
                log_message(f"[MES] ❌ SFC {sn} 不存在", log_file)
                return None
            
            sfc_data = data['SFC']
            log_message(f"[MES] ✅ SFC 信息获取成功", log_file)
            log_message(f"[MES]    型号: {sfc_data.get('PROJECT', 'N/A')}", log_file)
            log_message(f"[MES]    产线: {sfc_data.get('LINE', 'N/A')}", log_file)
            log_message(f"[MES]    工单: {sfc_data.get('SHOPORDER', 'N/A')}", log_file)
            log_message(f"[MES]    排程ID: {sfc_data.get('SCHEDULING_ID', 'N/A')}", log_file)
            
            return sfc_data
            
        except requests.exceptions.ConnectionError:
            retry_count += 1
            log_message(f"[MES] ⚠️ 连接错误，重试 {retry_count}/{max_retries}...", log_file)
            time.sleep(2)
        except requests.exceptions.Timeout:
            retry_count += 1
            log_message(f"[MES] ⚠️ 请求超时，重试 {retry_count}/{max_retries}...", log_file)
            time.sleep(2)
        except Exception as e:
            retry_count += 1
            log_message(f"[MES] ⚠️ 未知错误: {e}，重试 {retry_count}/{max_retries}...", log_file)
            time.sleep(2)
    
    log_message(f"[MES] ❌ 获取 SFC 信息失败，已重试 {max_retries} 次", log_file)
    return None

def mes_start(mes_ip, client_id, sn, station, sfc_data, log_file=None):
    """MES 开始"""
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36",
        "Cookie": "cookiesession1=426EF394ULRHIHCOMFONBBXJAGLM1F47;"
    }
    
    line = sfc_data.get('LINE', '')
    shoporder = sfc_data.get('SHOPORDER', '')
    scheduling_id = sfc_data.get('SCHEDULING_ID', '')
    
    url = f'http://{mes_ip}/Service.action?method=Start&param={{"LOGIN_ID":"-1","CLIENT_ID":"{client_id}","SFC":"{sn}","STATION_NAME":"{station}","LINE":"{line}","SHOPORDER":"{shoporder}","SCHEDULING_ID":"{scheduling_id}","WORK_STATION":"{station}"}}'
    
    log_message(f"[MES] 开始测试: {sn} @ {station}", log_file)
    log_message(f"[MES] URL: {url}", log_file)
    
    try:
        response = requests.get(url=url, headers=headers, timeout=5)
        data = json.loads(response.text)
        
        log_message(f"[MES] 响应: {json.dumps(data, ensure_ascii=False)}", log_file)
        
        if data['RESULT'] == 'PASS':
            log_message(f"[MES] ✅ {sn} START PASS", log_file)
            return True
        else:
            log_message(f"[MES] ❌ {sn} START FAIL", log_file)
            return False
            
    except Exception as e:
        log_message(f"[MES] ❌ 开始测试失败: {e}", log_file)
        return False

def mes_complete(mes_ip, client_id, sn, station, sfc_data, test_time="0", log_file=None):
    """MES 完成（良品）"""
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36",
        "Cookie": "cookiesession1=426EF394ULRHIHCOMFONBBXJAGLM1F47;"
    }
    
    line = sfc_data.get('LINE', '')
    shoporder = sfc_data.get('SHOPORDER', '')
    scheduling_id = sfc_data.get('SCHEDULING_ID', '')
    
    url = f'http://{mes_ip}/Service.action?method=Complete&param={{"LOGIN_ID":"-1","CLIENT_ID":"{client_id}","SFC":"{sn}","STATION_NAME":"{station}","LINE":"{line}","SHOPORDER":"{shoporder}","SCHEDULING_ID":"{scheduling_id}","TEST_TIME":"{test_time}","WORK_STATION":"{station}"}}'
    
    log_message(f"[MES] 完成测试（良品）: {sn} @ {station}", log_file)
    log_message(f"[MES] URL: {url}", log_file)
    
    try:
        response = requests.get(url=url, headers=headers, timeout=5)
        data = json.loads(response.text)
        
        log_message(f"[MES] 响应: {json.dumps(data, ensure_ascii=False)}", log_file)
        
        if data['RESULT'] == 'PASS':
            log_message(f"[MES] ✅ {sn} COMPLETE PASS", log_file)
            return True
        else:
            log_message(f"[MES] ❌ {sn} COMPLETE FAIL", log_file)
            return False
            
    except Exception as e:
        log_message(f"[MES] ❌ 完成测试失败: {e}", log_file)
        return False

def mes_nc_complete(mes_ip, client_id, sn, station, sfc_data, nc_code, nc_context, fail_item, fail_value, test_time="0", log_file=None):
    """MES 完成（不良品）"""
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36",
        "Cookie": "cookiesession1=426EF394ULRHIHCOMFONBBXJAGLM1F47;"
    }
    
    scheduling_id = sfc_data.get('SCHEDULING_ID', '')
    
    url = f'http://{mes_ip}/Service.action?method=NcComplete&param={{"LOGIN_ID":"-1","CLIENT_ID":"{client_id}","SFC":"{sn}","STATION_NAME":"{station}","SCHEDULING_ID":"{scheduling_id}","TEST_TIME":"{test_time}","NC_CODE":"{nc_code}","NC_CONTEXT":"{nc_context}","NC_TYPE":"{station}","FAIL_ITEM":"{fail_item}","FAIL_VALUE":"{fail_value}","WORK_STATION":"{station}"}}'
    
    log_message(f"[MES] 完成测试（不良品）: {sn} @ {station}", log_file)
    log_message(f"[MES]    不良代码: {nc_code}", log_file)
    log_message(f"[MES]    不良描述: {nc_context}", log_file)
    log_message(f"[MES]    失败项目: {fail_item}", log_file)
    log_message(f"[MES]    失败值: {fail_value}", log_file)
    log_message(f"[MES] URL: {url}", log_file)
    
    try:
        response = requests.get(url=url, headers=headers, timeout=5)
        data = json.loads(response.text)
        
        log_message(f"[MES] 响应: {json.dumps(data, ensure_ascii=False)}", log_file)
        
        if data['RESULT'] == 'PASS':
            log_message(f"[MES] ✅ {sn} NC_COMPLETE PASS", log_file)
            return True
        else:
            log_message(f"[MES] ❌ {sn} NC_COMPLETE FAIL", log_file)
            return False
            
    except Exception as e:
        log_message(f"[MES] ❌ 不良品完成失败: {e}", log_file)
        return False

def main():
    """主函数"""
    if len(sys.argv) < 4:
        print("用法: byd_mes_client.py <action> <sn> <station> [mes_ip] [client_id] [其他参数...]", file=sys.stderr)
        print("", file=sys.stderr)
        print("action: start | complete | nccomplete", file=sys.stderr)
        print("", file=sys.stderr)
        print("示例:", file=sys.stderr)
        print("  开始: python3 byd_mes_client.py start SN123456 STATION1 192.168.1.100 CLIENT001", file=sys.stderr)
        print("  完成: python3 byd_mes_client.py complete SN123456 STATION1 192.168.1.100 CLIENT001", file=sys.stderr)
        print("  不良: python3 byd_mes_client.py nccomplete SN123456 STATION1 192.168.1.100 CLIENT001 NC001 不良描述 失败项 失败值", file=sys.stderr)
        sys.exit(1)
    
    action = sys.argv[1].lower()
    sn = sys.argv[2]
    station = sys.argv[3]
    mes_ip = sys.argv[4] if len(sys.argv) > 4 else "192.168.1.100"
    client_id = sys.argv[5] if len(sys.argv) > 5 else "DEFAULT_CLIENT"
    
    # 日志文件
    current_date = datetime.now().strftime("%Y-%m-%d")
    log_file = f"{current_date}_mes.log"
    
    log_message(f"[MES] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", log_file)
    log_message(f"[MES] BYD MES 客户端", log_file)
    log_message(f"[MES] 操作: {action.upper()}", log_file)
    log_message(f"[MES] SN: {sn}", log_file)
    log_message(f"[MES] 工站: {station}", log_file)
    log_message(f"[MES] MES IP: {mes_ip}", log_file)
    log_message(f"[MES] Client ID: {client_id}", log_file)
    log_message(f"[MES] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", log_file)
    
    # 1. 获取 SFC 信息
    sfc_data = get_sfc_info(mes_ip, client_id, sn, log_file)
    if not sfc_data:
        log_message(f"[MES] ❌ 获取 SFC 信息失败", log_file)
        sys.exit(1)
    
    # 2. 执行操作
    success = False
    
    if action == "start":
        success = mes_start(mes_ip, client_id, sn, station, sfc_data, log_file)
        
    elif action == "complete":
        test_time = sys.argv[6] if len(sys.argv) > 6 else "0"
        success = mes_complete(mes_ip, client_id, sn, station, sfc_data, test_time, log_file)
        
    elif action == "nccomplete":
        if len(sys.argv) < 10:
            log_message(f"[MES] ❌ nccomplete 需要更多参数: nc_code nc_context fail_item fail_value", log_file)
            sys.exit(1)
        
        nc_code = sys.argv[6]
        nc_context = sys.argv[7]
        fail_item = sys.argv[8]
        fail_value = sys.argv[9]
        test_time = sys.argv[10] if len(sys.argv) > 10 else "0"
        
        success = mes_nc_complete(mes_ip, client_id, sn, station, sfc_data, nc_code, nc_context, fail_item, fail_value, test_time, log_file)
        
    else:
        log_message(f"[MES] ❌ 未定义的操作: {action}", log_file)
        sys.exit(1)
    
    log_message(f"[MES] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", log_file)
    
    if success:
        log_message(f"[MES] ✅ 操作成功", log_file)
        sys.exit(0)
    else:
        log_message(f"[MES] ❌ 操作失败", log_file)
        sys.exit(1)

if __name__ == "__main__":
    main()
