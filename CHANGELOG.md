## 1.0.0 (2025-04-19)

### Features

* add .pg_format configuration file for SQL formatting options ([222c331](https://github.com/humlab/sead_clearinghouse/commit/222c3311ea1062f7a89c62ebb6450c4e3dc0f801))
* add apa.sh script to list SQL files in deprecated directory ([e208e94](https://github.com/humlab/sead_clearinghouse/commit/e208e94609fd9571e17a2c713b69a00661fc069e))
* add deprecated SQL function and installation script for clearinghouse database ([a05edc6](https://github.com/humlab/sead_clearinghouse/commit/a05edc680e7ddbc7119ffa92cae04be557d0cad9))
* add function to resolve records by submission name (https://github.com/humlab-sead/sead_change_control/issues/367) ([b8f3491](https://github.com/humlab/sead_clearinghouse/commit/b8f3491edc799822cad4288e41cbec6aa0aef787))
* add function to retrieve max transported ID for primary key resolution ([c4698a6](https://github.com/humlab/sead_clearinghouse/commit/c4698a61abf2c453f7336f4fe51446625af93ae4))
* add procedure to create or update clearinghouse system with role management ([b4c499a](https://github.com/humlab/sead_clearinghouse/commit/b4c499a2ac9350e04612e1e12eb65119fb8115ba))
* add source_name column to tbl_clearinghouse_submissions for submission source tracking ([c8e9ec9](https://github.com/humlab/sead_clearinghouse/commit/c8e9ec9d459201b5db3f4aec873e6530095d75a7))
* assign pre-allocated identities when resolving primary keys ([#50](https://github.com/humlab/sead_clearinghouse/issues/50)) ([7ba3627](https://github.com/humlab/sead_clearinghouse/commit/7ba36278fac2b531daec435f12421c4179f7e847))
* enabling incremental updates of entity model ([ef5fe2d](https://github.com/humlab/sead_clearinghouse/commit/ef5fe2d4ba730e20567b7eb769c8d569de9d63c0))
* improved resolve of primary keys (https://github.com/humlab-sead/sead_change_control/issues/367) ([38dc482](https://github.com/humlab/sead_clearinghouse/commit/38dc482873d85a6ee2bc5367b721b57d7fb4cf23))
* update generate_copy_out_script to use p_submission_name parameter (https://github.com/humlab-sead/sead_change_control/issues/367) ([5982e2e](https://github.com/humlab/sead_clearinghouse/commit/5982e2e7e14cf1eca2d7a727b741e6c6ae30aad1))

### Bug Fixes

* add .env to .gitignore to prevent environment file from being tracked ([1363cb8](https://github.com/humlab/sead_clearinghouse/commit/1363cb843c023761d32aea8b290997e18754353e))
* correct syntax for default privileges in SQL script ([8ccd990](https://github.com/humlab/sead_clearinghouse/commit/8ccd990d06782bbf19ff8b898fc80294bf54f8a4))
* ensure correct owner of UDFs ([2693c73](https://github.com/humlab/sead_clearinghouse/commit/2693c737804ea648daf2da81f210b633d6942e7a))
* remove trailing comma from procedure parameter definition ([01bc12c](https://github.com/humlab/sead_clearinghouse/commit/01bc12cc9bc57867a0a5c911d2566cbade010c32))
* typo in schema name ([750eccc](https://github.com/humlab/sead_clearinghouse/commit/750ecccb31f8fdc3af704e137100cab2eede4eae))
