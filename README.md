# mCPR trajectories

The production model, report, inputs and execution scripts are in [`mcpr_trajectories/`](mcpr_trajectories/README.md).

- [Full project documentation and configurable file locations](mcpr_trajectories/README.md)
- [Saved HTML report](mcpr_trajectories/production_report.html)
- [R Markdown report source](mcpr_trajectories/production_report.Rmd)
- [Validation and scope](mcpr_trajectories/docs/VALIDATION.md)

To use the documented project defaults from this repository root:

```sh
Rscript mcpr_trajectories/run_pipeline.R --help
```

Then supply the authorized aggregate inputs and saved production fit using `--input-dir` and `--fit-cache`, or follow the project README for an authorized DHS refresh/refit. Output and staging locations are configurable. GitHub authentication is not required to run downloaded source files. Do not commit source microdata, account credentials or production-fit archives.
