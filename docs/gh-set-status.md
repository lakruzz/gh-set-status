# `gh set-status <state> <description>`

## Install:

`gh extension install thetechcollective/gh-set-status`

## Run:

`gh set-status success "All tests passed"``

## Args:

#### `state`

The state of the status.

- **required**: true
- **type**: string<br/>
  Must be one of `error`, `failure`, `pending`, `success`<br/>

#### `description`

The description of the status, as it will be presented on the commit status

- **required**: true
- **type**: string

## Derived values

- **`context`** will be the `id` of the stp that utilises `gh set-status`
- **`target_url** for the status (when you click details) will be a link to the GitHub action that set it

> [!WARNING]
> The script will fail if executed outside a GitHub Workflow Runner context

## Use case example

```yml
name: Wrapup
# This workflow is triggered on push to branches that begins with a number (issue-branches)

on:
  workflow_dispatch:
  push:
    branches:
      - "[0-9]*"

# No special permissions defined before we need them
permissions:
  contents: read

jobs:
  # This job will install uv, run the unittests and output the arguments we need to set the status
  verification:
    runs-on: ubuntu-latest
    permissions:
      statuses: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Python 3.13
        uses: actions/setup-python@v3
        with:
          python-version: "3.13"

      - name: Install dependencies
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          curl -LsSf https://astral.sh/uv/install.sh | sh
          uv venv
          . .venv/bin/activate
          uv sync --extra dev
          gh extension install thetechcollective/gh-set-status

      - name: Test with pytest
        id: Unittest
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          . .venv/bin/activate 
          pwd
          # Dont exit if the next command fails, we want to capture the exit code
          set +e
          pytest --cov=. --cov-config=.coveragerc -m unittest
          result=$?
          set -e


          if [ $result -eq 0 ]; then
            gh set-status success "All tests passed and threshold on line coverage reached"
          else
            gh set-status failure "Some tests failed or threshold on line covearage not reached"
          fi
          exit $result
```

> [!NOTE]
>
> 1. The `gh` extension must be installed in the same or a previous step: `gh extension install thetechcollective/gh-set-status`
> 2. Utilization of `gh` requires `$GH_TOKEN` to be set.
> 3. The `unittest` step inside `verification` sets the statuses itself
> 4. The `unittest` step must prevent the step from dying, even if the unittest fails (`set +e`), and it must manually capture the result and pass it on (`exit $result`)
> 5. The permissions `statuses: write` must be set on the job that contains steps that wish to utilize `gh set-status`

## Benefits over the callable workflow

- The statuses doesn't contain an arbitrary _extra_

<img width="574" alt="Image" src="https://github.com/user-attachments/assets/9f623d06-933b-4875-8282-a8ae7db72bef" />

- The `yml` workflow is way simpler to read.
