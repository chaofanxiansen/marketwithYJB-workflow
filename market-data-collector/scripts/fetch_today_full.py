# -*- coding: utf-8 -*-
"""2026-08-12 收盘复盘数据采集（东财 push2 + 腾讯双源，Python 路径）"""
import urllib.request, json, sys, io, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

def get_json(url, timeout=12):
    req = urllib.request.Request(url)
    req.add_header('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)')
    return json.loads(urllib.request.urlopen(req, timeout=timeout).read().decode('utf-8'))

def get_text(url, enc='gbk', timeout=12):
    req = urllib.request.Request(url)
    req.add_header('User-Agent', 'Mozilla/5.0')
    return urllib.request.urlopen(req, timeout=timeout).read().decode(enc, errors='replace')

# ---------- 1. A股指数（腾讯为主，含成交额） ----------
def tencent_quote(codes):
    url = 'https://qt.gtimg.cn/q=' + ','.join(codes)
    data = get_text(url)
    result = {}
    for line in data.strip().split(';'):
        if not line.strip() or '=' not in line or '"' not in line: continue
        vals = line.split('"')[1].split('~')
        if len(vals) < 45: continue
        result[vals[1]] = vals
    return result

print("===== A股指数（腾讯） =====")
q = tencent_quote(['sh000001','sz399001','sz399006','sh000688','sh000300'])
for name, v in q.items():
    amt_yi = float(v[37]) / 1e4  # 万元 -> 亿元
    print(f"{name}: 收{v[3]}  涨{v[31]}  {v[32]}%  成交额{amt_yi:.0f}亿")

# ---------- 2. 市场广度（东财 f104涨/f105跌/f106平） ----------
print("\n===== 市场广度（东财） =====")
for secid, label in [("1.000001","沪市"), ("0.399001","深市")]:
    try:
        b = get_json(f'https://push2.eastmoney.com/api/qt/ulist.np/get?fltt=2&secids={secid}&fields=f104,f105,f106')
        d = b.get('data',{}).get('diff',[{}])[0]
        print(f"{label}: 涨{d.get('f104','?')} 跌{d.get('f105','?')} 平{d.get('f106','?')}")
    except Exception as e:
        print(f"{label}: 失败 {e}")

# ---------- 3. 涨停/跌停池 ----------
print("\n===== 涨跌停池（东财） =====")
try:
    zt = get_json('https://push2ex.eastmoney.com/getTopicZTPool?ut=7eea3edcaed734bea9cbfc24409ed989&dpt=wz.ztzt&Pageindex=0&pagesize=10&sort=fbt:asc&date=')
    ztc = zt.get('data',{}).get('tc','n/a')
    print(f"涨停总数: {ztc}")
    for it in zt.get('data',{}).get('pool',[])[:8]:
        print(f"  {it.get('n')}: {it.get('zdp',0):.2f}%  连板{it.get('lbc',1)}")
except Exception as e:
    print(f"涨停池失败: {e}")
try:
    dt = get_json('https://push2ex.eastmoney.com/getTopicDTPool?ut=7eea3edcaed734bea9cbfc24409ed989&dpt=wz.ztzt&Pageindex=0&pagesize=5&sort=fund:asc&date=')
    print(f"跌停总数: {dt.get('data',{}).get('tc','n/a')}")
    for it in dt.get('data',{}).get('pool',[])[:5]:
        print(f"  {it.get('n')}: {it.get('zdp',0):.2f}%")
except Exception as e:
    print(f"跌停池失败: {e}")

# ---------- 4. 板块资金流 + 概念涨幅榜（东财 clist） ----------
print("\n===== 行业板块资金流入TOP8（东财） =====")
try:
    sec = get_json('https://push2.eastmoney.com/api/qt/clist/get?pn=1&pz=8&po=1&np=1&fltt=2&invt=2&fid=f62&fs=m:90+t:2&fields=f12,f14,f3,f62')
    for it in sec.get('data',{}).get('diff',[]):
        print(f"  {it['f14']}: {it['f3']}%  净流入{float(it['f62'])/1e8:.1f}亿")
except Exception as e:
    print(f"失败: {e}")

print("\n===== 行业板块资金流出TOP5（东财） =====")
try:
    sec2 = get_json('https://push2.eastmoney.com/api/qt/clist/get?pn=1&pz=5&po=0&np=1&fltt=2&invt=2&fid=f62&fs=m:90+t:2&fields=f12,f14,f3,f62')
    for it in sec2.get('data',{}).get('diff',[]):
        print(f"  {it['f14']}: {it['f3']}%  净流入{float(it['f62'])/1e8:.1f}亿")
except Exception as e:
    print(f"失败: {e}")

print("\n===== 概念涨幅榜TOP10（东财） =====")
try:
    cg = get_json('https://push2.eastmoney.com/api/qt/clist/get?pn=1&pz=10&po=1&np=1&fltt=2&invt=2&fid=f3&fs=m:90+t:3&fields=f12,f14,f3,f62')
    for it in cg.get('data',{}).get('diff',[]):
        print(f"  {it['f14']}: {it['f3']}%  主力净流入{float(it['f62'])/1e8:.1f}亿")
except Exception as e:
    print(f"失败: {e}")

# ---------- 5. 全球指数 ----------
print("\n===== 全球指数（东财） =====")
try:
    g = get_json('https://push2.eastmoney.com/api/qt/ulist.np/get?fltt=2&secids=100.HSI,100.HSTECH,100.DJIA,100.NDX,100.IXIC,100.SPX,100.N225,100.KS11,100.TWII,100.FTSE,100.GDAXI&fields=f2,f3,f4,f12,f14')
    for it in g.get('data',{}).get('diff',[]):
        print(f"  {it['f14']}: {it['f2']}  {it['f3']}%")
except Exception as e:
    print(f"失败: {e}")

# ---------- 6. 汇率/美元指数 ----------
print("\n===== 汇率/美元指数（东财） =====")
try:
    fx = get_json('https://push2.eastmoney.com/api/qt/ulist.np/get?fltt=2&secids=133.USDCNH,133.USDCNY,133.EURCNY,133.JPYCNY,100.UDI&fields=f2,f3,f12,f14')
    for it in fx.get('data',{}).get('diff',[]):
        print(f"  {it['f14']}: {it['f2']}  {it['f3']}%")
except Exception as e:
    print(f"失败: {e}")

# ---------- 7. 商品（新浪，字段0=最新, 字段7=昨收） ----------
print("\n===== 商品（新浪） =====")
try:
    url = 'https://hq.sinajs.cn/list=hf_GC,hf_CL,hf_SI'
    req = urllib.request.Request(url)
    req.add_header('User-Agent','Mozilla/5.0'); req.add_header('Referer','https://finance.sina.com.cn')
    txt = urllib.request.urlopen(req, timeout=10).read().decode('gbk', errors='replace')
    for line in txt.strip().split('\n'):
        m = re.search(r'hf_(\w+)="([^"]*)"', line)
        if m and m.group(2):
            code, f = m.group(1), m.group(2).split(',')
            if len(f) >= 8 and f[0] and f[7]:
                chg = (float(f[0]) / float(f[7]) - 1) * 100
                name = {'GC':'COMEX黄金','CL':'WTI原油','SI':'COMEX白银'}.get(code, code)
                print(f"  {name}: {f[0]}  {chg:+.2f}%  昨收{f[7]}")
except Exception as e:
    print(f"商品失败: {e}")

print("\n[DONE]")
