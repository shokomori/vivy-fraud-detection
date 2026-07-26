# AI-fraud expansion attempt: motivation, experiment, and final decision

## Motivation

The goal of the AI-fraud expansion work was to test whether adding a new AI-fraud category could improve the fraud detector on the target domain, particularly under the thesis requirement to explore a broader fraud distribution. The working hypothesis was that additional AI-fraud examples might improve robustness to modern fraud patterns while preserving the original detection behavior.

## Dataset audit and triage process

Before any training was attempted, the added AI-fraud data were audited rather than used blindly. The audit focused on:

1. verifying that the new samples were structurally consistent with the existing fraud class,
2. checking whether they were visually similar to the original Canva-edited fraud subset or whether they represented a materially different distribution,
3. identifying high-risk genuine samples that might be especially sensitive to a shifted fraud definition.

The audit produced a triage view of the AI-fraud set and highlighted a small number of genuine samples that were especially important for guardrail testing. In particular, the hard seven genuine samples were retained as a holdout set for evaluating whether the model would preserve genuine behavior while learning the new category.

## Training attempts

### 1. Full retrain from the original training recipe

The first attempt retrained the model using the expanded dataset in a standard way. This was the most direct test of whether the enlarged AI-fraud distribution could be integrated without additional constraints.

Results: the model improved fraud recall on the expanded condition, but the gain came with a clear regression in genuine-sample behavior, including elevated false positives on genuine cases and a visible loss of confidence in the old genuine-vs-fraud boundary.

### 2. Guardrail retrain with selective preservation

The second attempt used a more conservative retraining recipe. The model was initialized from the original checkpoint and fine-tuned with guardrails intended to preserve the original genuine behavior and hard seven holdout performance.

This attempt still showed that the inclusion of AI-fraud examples was destabilizing the decision boundary in a way that was not easily contained by a light retraining regime.

### 3. Conservative subset sweep (10/20/30 AI-fraud samples)

The third attempt tested whether a very small amount of AI-fraud data could be integrated safely. The sweep used the original checkpoint as the starting point, held out the hard seven genuine samples from training, and applied strict acceptance gates:

- all hard seven genuine samples must remain genuine at threshold 0.16,
- non-AI behavior must match or beat the original model,
- overall fraud recall must remain at or above 0.98.

Even at the smallest tested subset size of 10 AI-fraud examples, the model failed the gates.

## Failure evidence

The decisive evidence came from direct baseline comparison on two genuine samples that were important in the guardrail analysis:

- gA_272.jfif: the original pre-AI model scored 0.000052 and predicted genuine.
- gI_059.jpg: the original pre-AI model scored 0.002332 and predicted genuine.

These scores were extremely confident and far from borderline. They show that the original model had comfortably handled these samples before AI-fraud data were introduced.

After AI-fraud inclusion, even the smallest tested 10-image subset caused these samples to become problematic under the same threshold, which indicates that the regression came from the AI-fraud inclusion itself rather than from a pre-existing weakness in the dataset.

## Final decision

Because the AI-fraud inclusion caused genuine-sample regressions even at the smallest evaluated subset and failed the strict acceptance criteria, the experiment was stopped.

The original pre-AI-expansion model was retained as the production model. The AI-fraud expansion was treated as an attempted but unsuccessful direction rather than as a model update. This is a legitimate and defensible methodological outcome: the experiment tested a plausible extension, gathered evidence, and demonstrated that the added category did not integrate safely under the available data regime.
