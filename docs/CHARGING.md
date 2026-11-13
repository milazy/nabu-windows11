# Charging on nabu (Windows) — research notes

Community status: "slow charging only, only in USB-Fn mode".

Charger chain on SM8150 + nabu: PM8150B charger (USB input current limit, HVDCP/QC detection, USB-PD via the PMIC
Type-C/PD block), battery fuel gauge, plus Xiaomi's charge-pump (on Android: bq25970 / ln8000 class).
Windows driver set in v2608.03 (components/QC8150/Drivers):
- `Battery/BatteryManager/qcbattmngr8150` and `Devices/Nabu/.../MiPad5_battminiclass` (qcbattminiclass8150.sys)
- `SOC/PMIC/*` (core, apps, extension, ExternalIC "EIC", GLINK, GPIO, TypeCController)
- `USB/UCSI/qcusbcucsi8150`

Plan:
1. On the running tablet: record what the charger reports (Battery report, ACPI _BIX/_BST, PMIC driver logs) with a
   plain 5 V charger, a QC charger and a PD charger.
2. Find where the input current limit comes from (UEFI charger config / ACPI / driver registry).
3. Only raise limits inside the tablet's rated 33 W and the battery's charge-current limit, step by step, with temperature
   checks; never bypass thermal or battery protection.
4. If no setting exists: a KMDF filter/driver that negotiates HVDCP/PD and programs the charger within those limits.

## Measurements on this tablet (UGREEN 120 W USB-PD charger, screen on)
Windows.Devices.Power.Battery aggregate report, 5 s samples:

| USB role (`HKLM\SYSTEM\CurrentControlSet\Enum\ACPI\QCOM0597\0\Device Parameters\RoleSwitchMode`) | Net battery rate |
|---|---|
| 3 (default after install, host controller active) | −8 … −54 mW while "Charging"; −9 W when the input dropped. Battery report: AC/Battery flipping every few seconds |
| **2 (USB function / device mode)** | **+6651 mW** steady |

Setting it (as Administrator), then the controller restarts:
```
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Enum\ACPI\QCOM0597\0\Device Parameters' RoleSwitchMode 2 -Type DWord
pnputil /restart-device "ACPI\QCOM0597\0"
```
(same mechanism as n00b69/usbhostmode: 1 = host, 2 = function). Trade-off: USB devices plugged into the tablet do not work in mode 2.
+6.65 W net with the screen on means roughly 13–15 W in: about 5 V / 3 A (Type-C current), not a PD contract.
Next: PD negotiation (9 V) through the PMIC Type-C/PD block, within the 33 W rating.

## 2026-11-13 — Findings: PD already works, charge current is capped

Measured on Windows 11 26100, UEFI v2608.03 nSB, UGREEN 120 W charger, RoleSwitchMode=2.

**ACPI (DSDT from the UEFI, `\_SB.UCP0.CON0._DSD`, UUID 6b856e62-…-5e888a2260de):**
PD supported, DRP, source PDO 5 V/1.5 A, sink PDOs 5 V/3 A, 9 V/2 A, 12 V/1.5 A (max 18 W).

**Battery manager config (`\_SB.PMBT`, decoded against qcbattmngr8150.sys strings):**

| Method | Meaning | Value |
|---|---|---|
| BJTA/BCT1 | FloatVoltage, FullChargeCurrent, JEITA 0/10/45/59 °C | 4450 mV, 5900 mA |
| BPCH | HVDCP, HVDCPv3, IWallChargerCurrent | 2100, 3000, **1500 mA** |
| BFCH | Foldback: enable, attach/detach count, window, current | 1, 5, 5000 ms, 900 mA |
| BMPC | Parallel charging (disabled) | FeatureEnable=0 |

**ETW (Microsoft-Windows-Power-CAD, event 209) on re-plug:** first 5 V/3000 mA (Type-C),
150 ms later **12 V/1500 mA, Flag=2 (PD contract)**.

**Battery side:** constant ~1.57 A (≈6.8 W at 4.33 V), system draw ≈5 W unplugged.
Input ≈12–13 W of the 18 W contract → the limit is a ~1.5 A charge-current cap, matching
either CAD MaxCurrent (1500 mA at 12 V) or IWallChargerCurrent (1500 mA).

### Test UEFI (temporary boot only)

`tools/build_uefi_fastcharge.py` rebuilds the boot image with two same-size DSDT edits:
sink PDO 9 V/2 A → 9 V/3 A (27 W, below the 33 W rating) and IWallChargerCurrent 1500 → 3000 mA.
JEITA, foldback, BCL and Type-C thermal mitigation are untouched. Test with `fastboot boot`
(nothing is flashed; a normal reboot returns to the stock nSB UEFI).

### Test 1 result (PDO 9 V/3 A + IWall 3000 together) — rejected

PD contract became **9 V / 3000 mA (Flag=2)**, but the battery kept **discharging** at about −2…−3 W
while plugged in (system ≈ 5 W, so only about 3 W was drawn from the charger). The temperature stayed
at 33–34 °C. Next: separate tests, A = PDO 9 V/3 A only, B = IWall 3000 only
(`SEL=pdo` / `SEL=iwall` in `tools/build_uefi_fastcharge.py`).
