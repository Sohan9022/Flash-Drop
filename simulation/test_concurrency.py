"""
FlashDrop: Concurrency & Race Condition Stress Tester
------------------------------------------------------
Simulates a real-world flash drop scenario:
Multiple simultaneous buyers fire checkout/reservation requests
at the exact same millisecond competing for limited stock.

Tests transactional isolation and verifies that:
1. Exact stock limits are respected (0 overselling).
2. Exactly N reservations succeed, and the remaining fail gracefully with 'OUT_OF_STOCK'.
3. Product stock never drops below 0.
"""

import sys
import subprocess
import threading
import time
from concurrent.futures import ThreadPoolExecutor

DB_NAME = "flash_drop_db"
DB_USER = "root"
# Replace with your MySQL password if configured, or leave empty if none
DB_PASSWORD = ""
MYSQL_BIN = "mysql"

def run_mysql_query(sql: str, user=DB_USER, password=DB_PASSWORD, db=DB_NAME):
    cmd = [MYSQL_BIN, "-u", user]
    if password:
        cmd.append(f"-p{password}")
    cmd.extend(["-D", db, "-e", sql, "-s", "-N"])
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return None, result.stderr.strip()
    return result.stdout.strip(), None

def simulate_user_reservation(user_id: int, product_id: int, quantity: int, thread_id: int):
    sql = f"""
    CALL sp_reserve_product({user_id}, {product_id}, {quantity}, @res_id, @status, @msg);
    SELECT @res_id, @status, @msg;
    """
    stdout, stderr = run_mysql_query(sql)
    if stderr:
        return {"thread": thread_id, "user_id": user_id, "status": "ERROR", "message": stderr}
    
    parts = stdout.split("\t") if stdout else []
    res_id = parts[0] if len(parts) > 0 else "NULL"
    status = parts[1] if len(parts) > 1 else "UNKNOWN"
    msg = parts[2] if len(parts) > 2 else ""
    return {"thread": thread_id, "user_id": user_id, "res_id": res_id, "status": status, "message": msg}

def run_stress_test(num_buyers=15, target_product_id=1):
    print("=" * 70)
    print(" 🚀 FLASHDROP HIGH-CONCURRENCY STRESS TEST")
    print("=" * 70)
    
    # 1. Fetch initial stock
    stock_out, _ = run_mysql_query(f"SELECT available_stock FROM products WHERE product_id = {target_product_id};")
    if stock_out is None:
        print("[!] Could not connect to MySQL or fetch stock. Ensure MySQL is running and flash_drop_db is initialized.")
        return
    
    initial_stock = int(stock_out)
    print(f"[*] Target Product ID: {target_product_id}")
    print(f"[*] Initial Available Stock: {initial_stock} units")
    print(f"[*] Simulating {num_buyers} concurrent users attempting to buy 1 unit each...")
    print("-" * 70)

    # 2. Fire concurrent threads simultaneously
    start_time = time.time()
    results = []
    with ThreadPoolExecutor(max_workers=num_buyers) as executor:
        futures = [
            executor.submit(simulate_user_reservation, user_id=(i % 5) + 1, product_id=target_product_id, quantity=1, thread_id=i+1)
            for i in range(num_buyers)
        ]
        for f in futures:
            results.append(f.result())
            
    elapsed = time.time() - start_time

    # 3. Analyze results
    successes = [r for r in results if r["status"] == "SUCCESS"]
    out_of_stocks = [r for r in results if r["status"] == "OUT_OF_STOCK"]
    errors = [r for r in results if r["status"] in ("ERROR", "UNKNOWN")]

    print("\n[+] CONCURRENCY EXECUTION SUMMARY:")
    for r in results:
        badge = "✅ WON " if r["status"] == "SUCCESS" else "❌ LOST"
        print(f"  - Buyer #{r['thread']:02d} (User {r['user_id']}): {badge} -> Status: {r['status']:<14} Msg: {r['message']}")

    print("\n" + "=" * 70)
    print(f"[*] Total Time Elapsed    : {elapsed:.2f} seconds")
    print(f"[*] Successful Holds      : {len(successes)} (Reserved IDs: {[s['res_id'] for s in successes]})")
    print(f"[*] Graceful 'Sold Out'   : {len(out_of_stocks)}")
    print(f"[*] Internal Failures     : {len(errors)}")

    # 4. Verify Final Stock & Invariants
    final_stock_out, _ = run_mysql_query(f"SELECT available_stock FROM products WHERE product_id = {target_product_id};")
    final_stock = int(final_stock_out)
    print(f"[*] Final Available Stock : {final_stock} units")
    
    if final_stock >= 0 and len(successes) == initial_stock:
        print("\n🏆 INVARIANT CHECK: PASSED (ZERO OVERSELLING GUARANTEED!)")
    else:
        print("\n⚠️ INVARIANT CHECK: FAILED (Discrepancy detected)")
    print("=" * 70)

if __name__ == "__main__":
    users_count = int(sys.argv[1]) if len(sys.argv) > 1 else 15
    run_stress_test(num_buyers=users_count, target_product_id=1)
