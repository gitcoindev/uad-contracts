import math

multipliers = []
for d in range(1, 209):
    result = 1 + 0.001 * math.sqrt(d**3)
    multipliers.append(result)

bonds_to_fix = [1301000000000000000, 
                74603879373206500005186,
                44739174270101943975392,
                1480607760433248019987,
                9351040526163838324896,
                8991650309086743220575]

bonds_lock_time_weeks = [176, 208, 208, 2, 208, 208];

# UbiquityFormulas contract durationMultiply to get correct number of shares
# that should have been deposited to MasterChefV2 contract for given number of weeks
# with default bonding discount multiplier = 0.0001
# https://etherscan.io/address/0x54F528979A50FA8Fe99E0118EbbEE5fC8Ea802F7#readContract#F3
# e.g. 74603879373206500005186, 208, 1000000000000000 returns 298401988913823580096197 shares

correct_number_of_shares = [
    4338709911985672143,
    298401988913823580096197,
    178948584131608045237605,
    1484795551583967127527,
    37402466398057038362881,
    35964970701144371859332
]

bond_lock_blocks = [21124941, 22618922, 22624203, 13044314, 22647574, 22676978]

shares_difference_to_compensate = []

for i, current_shares in enumerate(bonds_to_fix):
    bond_id = i + 1
    bond_lock_time_weeks = bonds_lock_time_weeks[i]
    print(f"Bond {bond_id} locked for {bond_lock_time_weeks} weeks")

    correct_multiplier = multipliers[bond_lock_time_weeks - 1]
    # shares = current_shares * correct_multiplier
    # shares_difference_to_compensate.append(shares - current_shares)

    shares_difference_to_compensate.append(correct_number_of_shares[i] - current_shares)
    print(f"Correct multiplier {correct_multiplier} correct number of shares {correct_number_of_shares[i]}")
    print(f"Shares to compensate {correct_number_of_shares[i] - current_shares}")
    print(f"---")

def pendingUGOV(shares, accuGOVPerShare):
    return (shares * accuGOVPerShare) / 1e12

print("How much UBQ to compensate taking into account today's accuGOVPerShare")

# Permalink to up to date accuGOVPerShare https://etherscan.io/address/0xdae807071b5AC7B6a2a343beaD19929426dBC998#readContract#F6
accuGOVPerShare = 10838383916596 #  div e12 (10.838383916596)
print(accuGOVPerShare / 1e12)

for i, shares in enumerate(shares_difference_to_compensate, 1):
    print(f"Bond {i} : {int(pendingUGOV(shares, accuGOVPerShare))} ({(pendingUGOV(shares, accuGOVPerShare) / 1e18)}) UBQ")

print(f"---")

print("Let's simulate how much UBQ to compensate taking into account accuGOVPerShare at bonds expiration block")
# Permalink to _totalShares https://etherscan.io/address/0xdae807071b5AC7B6a2a343beaD19929426dBC998#readContract#F7
_totalShares = 589734727901953707250584
# Permalink to uGOVmultiplier https://etherscan.io/address/0xdae807071b5AC7B6a2a343beaD19929426dBC998#readContract#F10
uGOVmultiplier = 932569367439205616
uGOVPerBlock = 1e18
current_block = 19403957

for i, shares in enumerate(shares_difference_to_compensate, 1):
    number_of_blocks = bond_lock_blocks[i - 1] - current_block
    rewardMultiplier = number_of_blocks * uGOVmultiplier

    uGOVReward = (rewardMultiplier * uGOVPerBlock) / 1e18;
    accuGOVPerShare = accuGOVPerShare + ((uGOVReward * 1e12) / _totalShares)

    if number_of_blocks > 0:
        print(f"Bond {i} : {int(pendingUGOV(shares, accuGOVPerShare))} ({(pendingUGOV(shares, accuGOVPerShare) / 1e18)}) UBQ")
    else:
        print(f"Bond {i} : already expired")

print(f"---")

