# PwshProfile.AzureCompute changelog

## [1.0.0]

- Default ordinary and priced size results to wrapped tables, with region/OS/currency context above pricing rows.
- Add regional VM size discovery with name, vCPU, memory and architecture filters.
- Show enabled and total vCPUs, zones, capabilities and subscription restrictions.
- Keep restricted sizes visible without implying capacity or quota availability.
- Complete all 63 reported physical regions using an independently embedded list.
- Refresh regions through the catalogue workflow and prepare a Compute patch only when its region list changes.
- Add opt-in PAYG retail hourly and 730-hour monthly estimates with Linux/Windows price bases and selectable currency.
- Cache complete regional pricing responses for one hour; keep missing or ambiguous rates unknown and preserve SKU results during pricing outages.
- Exclude Spot, Low Priority, Dev/Test, reservation and software-specific meters; retain numeric amounts and precise hourly table output.
