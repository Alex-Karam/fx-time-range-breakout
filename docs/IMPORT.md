# Import the original study

Extract both CSVs from the input archive. Each archived entry matches the SHA-256
fingerprint recorded when the original study was imported.
[Input archive](../data/TRB06_SL100_inputs.zip)

| Input | Purpose | Expected rows excluding header |
|---|---|---:|
| `TRB06_SL100_scans.csv` | Scan metadata and source hashes | 28 |
| `TRB06_SL100_results.csv` | Configuration metrics and timing parameters | 318,136 |

| Extracted file | SHA-256 |
|---|---|
| `TRB06_SL100_scans.csv` | `89e421aab24179172ef2f490ab171442f3a1f33a4b179da353e707a36043fcc6` |
| `TRB06_SL100_results.csv` | `6917e3e655c97861c7f6fb6f8dfd4290ccfe149f11d9be94c40b6920ec4c9336` |

## Load the data

1. Run the schema script on a reproduction instance to create the four empty
   tables. [Schema script](../sql/01_schema.sql)
2. Run Step 1 of the import script. It reports the directory allowed by
   `secure_file_priv` and checks that the four tables are empty.
   [Import script](../sql/load_data.sql)
3. Place the two CSVs in the allowed directory and substitute their absolute
   server-side paths in the script. The server reads the files and the MySQL
   account needs the `FILE` privilege.
   [MySQL import requirements](https://dev.mysql.com/doc/refman/8.0/en/load-data.html)
4. Run Steps 2 and 3 in the same MySQL session. Use the original UTF-8 exports
   with LF line endings. The results loader interprets `\N` as SQL `NULL`,
   which preserves missing profit factors. Confirm 318,136 staged rows,
   28 source hashes, 31,304 missing profit factors and zero unmatched rows.
5. Run Step 4 to attach the scan IDs. In the same session, run Checks 1 and 2
   before committing. Check the warnings and expected counts, then execute
   `COMMIT` separately. If a load fails or the counts differ, run `ROLLBACK`
   in that session before retrying. [Expected controls](VALIDATION.md)
6. Create the reporting view and run Checks 3 and 4. The analysis queries then
   use the validated view. [Reporting view](../sql/02_reporting_view.sql)

On 11 November 2026, the import was reproduced in a newly created schema on the
same MySQL server. The server-side CSVs matched the archived files by SHA-256.
The staging counts matched, and the transfer inserted 318,136 rows with zero
duplicates and zero warnings. Checks 1 and 2 passed before commit. The reporting
view, Checks 3 and 4, and all three analysis queries were verified after commit.
