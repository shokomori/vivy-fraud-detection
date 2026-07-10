from pathlib import Path
import pandas as pd

root = Path(__file__).resolve().parents[1]
history = pd.read_csv(root / "artifacts" / "stage4" / "training_history.csv")

# Fine-tune marker in training_curves.png is at epoch 9.5 -> head phase epochs 1..9.
head_end = 9
head = history.iloc[:head_end].copy()
fine = history.iloc[head_end:].copy()

for name, df in [("head", head), ("fine", fine)]:
    best_val_acc_row = df["val_binary_accuracy"].idxmax()
    best_val_loss_row = df["val_loss"].idxmin()
    last_row = df.iloc[-1]

    print(f"[{name}] epochs={len(df)}")
    print(
        f"  best_val_acc={df.loc[best_val_acc_row, 'val_binary_accuracy']:.6f} "
        f"(epoch={best_val_acc_row + 1})"
    )
    print(
        f"  best_val_loss={df.loc[best_val_loss_row, 'val_loss']:.6f} "
        f"(epoch={best_val_loss_row + 1})"
    )
    print(
        f"  last_val_acc={last_row['val_binary_accuracy']:.6f} "
        f"last_val_loss={last_row['val_loss']:.6f}"
    )
