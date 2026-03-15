# `set_status.yml`

## Location:

`thetechcollective/set_status/.github/workflows/set_status.yml@1`

This is the string you apply in the `uses` clause in a job in the caller workflow.

You can can append the string with `@<ref>` where ´<ref>`is a valid commit reference of either a`sha`, `branch`or`tag`

<details><summary><b>Some pinning examples:</b></summary>

**Branches**:<br/>
`lakruzz/set_status/.github/workflows/set_status.yml@main`
`lakruzz/set_status/.github/workflows/set_status.yml@dev_set_status`

**tags**<br/>
`lakruzz/set_status/.github/workflows/set_status.yml@1`
`lakruzz/set_status/.github/workflows/set_status.yml@1.0.23rc`

**shas**<br/>
`lakruzz/set_status/.github/workflows/set_status.yml@b63bce3`
`lakruzz/set_status/.github/workflows/set_status.yml@ef383c3b0f7ea7ccd4699a012cd1b7de371b367f`

</details>

## Args:

#### `state`

The state of the status.

- **required**: true
- **type**: string<br/>
  Must be one of `error`, `failure`, `pending`, `success`<br/>

#### `context`

The name of the status, as it will be presented on the commit status

- **required**: true
- **type**: string

#### `description`

The description of the status, as it will be presented on the commit status

- **required**: true
- **type**: string

#### `url`

The URL to open in the 'details' link on the commit status.

If ommitted this will be set to the link to the action that set the status

- **required**: false
- **type**: string
- **default**: `${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}`

## Required permissions:

#### `statuses: write`

## Example use:

Reused workflows can not run as steps within jobs, but must be declared as seperate jobs. This requires that the jobs can communicate to each other.

The most typical use case would then be that you have another job run a test or verifcation and then expect that job to produce and output the arguments you pass to the `set_status.yml` floow

```yml
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

    # The output from this job is defiend from the step that runs the unittest
    outputs:
      state: ${{ steps.unittest.outputs.state }}
      description: ${{ steps.unittest.outputs.description }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Python 3.13
        uses: actions/setup-python@v3
        with:
          python-version: "3.13"

      - name: Install uv and dependencies
        run: |
          curl -LsSf https://astral.sh/uv/install.sh | sh
          uv venv
          . .venv/bin/activate
          uv sync --extra dev

      - name: Test with pytest
        id: unittest
        run: |
          . .venv/bin/activate 
          # Dont exit if the next command fails, we want to capture the exit code
          set +e
          pytest --cov=. --cov-config=.coveragerc -m unittest
          result=$?
          set -e

          if [ $result -eq 0 ]; then
            echo "state=success" >> $GITHUB_OUTPUT
            echo "description=All tests passed and threshold on line covearage reached" >> $GITHUB_OUTPUT
          else
            echo "state=failure" >> $GITHUB_OUTPUT
            echo "description=Some tests failed or threshold on line covearage not reached" >> $GITHUB_OUTPUT
          fi
          exit $result

  set_unittest_status:
    needs: verification
    if: always()
    permissions:
      statuses: write
    uses: thetechcollective/set_status/.github/workflows/set_status.yml@main
    with:
      state: ${{ needs.verification.outputs.state }}
      description: ${{ needs.verification.outputs.description }}
      context: Unittests
```

> [!NOTE]
>
> 1. The `verification` job defines `outputs`.
> 2. The `unittest` step inside `verification` sets the values. For this to be possible the step needs an `id`
> 3. The `unittest` step must prevent the step from dying, even if the unittest fails (`set +e`), and it must manually capture the result and pass it on (`exit $result`)
> 4. The `set_unittest_status` must be a `job` (can not be a `step` inside a `job`) and it must use the `if:always()` clause to ensure that status are set, even if the unittest failed.
> 5. The `set_unittest_status` job must raise the `statuses: write` permissions

## Hmmm - undesired side effects

When using a callable workflow the constraint that it must be a seperate job, it can not run as a step inside a job, calls for some verbose code, and the side effect that the `set_unittest_status` job itself will also have a status on the commit.

<img width="576" alt="image" src="https://github.com/user-attachments/assets/289bd5be-935b-429a-9a8f-21109d9d8f4d" />

We get that 1/3 jobs succeeded this seems both noisy, unnecessary and even kinda wrong. It's probably possible to null this status somehow, with another API call, but that just defies the entire purpose that we vant cleaner code, not more bloated code.
