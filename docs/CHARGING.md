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
