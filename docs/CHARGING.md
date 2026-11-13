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
