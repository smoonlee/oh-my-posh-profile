# PwshProfile.Dns changelog

## [1.0.1] - 2026-09-08

- Route unsupported native record types, including CAA, through dig while
  preserving the requested DNS server; explain the dependency if dig is absent.
- Report failed queries in `-All` and distinguish dig response errors from empty answers.

## [1.0.0] - 2026-09-01

- Initial release with `Get-DnsResult`.
