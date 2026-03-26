"""
RAG vs Baseline Benchmark 可視化腳本
產出多種圖表供 FYP 報告使用
"""
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib
import os, glob

matplotlib.rcParams['font.family'] = 'DejaVu Sans'

# ── Auto-find latest CSV results ──
eval_dir = os.path.dirname(os.path.abspath(__file__))
detail_files = sorted(glob.glob(os.path.join(eval_dir, 'benchmark_results_*.csv')))
summary_files = sorted(glob.glob(os.path.join(eval_dir, 'benchmark_summary_*.csv')))
if not detail_files or not summary_files:
    raise FileNotFoundError('Benchmark CSV not found. Please run rag_benchmark.py first.')

detail_path = detail_files[-1]
summary_path = summary_files[-1]
print(f'Loading: {os.path.basename(detail_path)}')

df = pd.read_csv(detail_path)
summary = pd.read_csv(summary_path)

out_dir = os.path.join(eval_dir, 'charts')
os.makedirs(out_dir, exist_ok=True)

NUTRIENTS = ['calories', 'protein', 'carbs', 'fat']
LABELS_EN = {'calories': 'Calories (kcal)', 'protein': 'Protein (g)',
              'carbs': 'Carbohydrates (g)', 'fat': 'Fat (g)'}
COLORS = {'baseline': '#FF6B6B', 'rag': '#4ECDC4'}


# ═══════════════════════════════════════════════════════════
# 圖 1：MAE 對比柱狀圖（附改善百分比標註）
# ═══════════════════════════════════════════════════════════
def plot_mae_comparison():
    fig, ax = plt.subplots(figsize=(10, 6))
    x = np.arange(len(NUTRIENTS))
    w = 0.35
    baseline_mae = summary['baseline_mae'].values
    rag_mae = summary['rag_mae'].values
    improve = summary['improvement_mae_pct'].values

    bars1 = ax.bar(x - w/2, baseline_mae, w, label='Baseline (AI only)', color=COLORS['baseline'], edgecolor='white')
    bars2 = ax.bar(x + w/2, rag_mae, w, label='RAG (AI + CFS)', color=COLORS['rag'], edgecolor='white')

    for i, (b, r, imp) in enumerate(zip(baseline_mae, rag_mae, improve)):
        ax.text(i - w/2, b + 0.3, f'{b:.1f}', ha='center', va='bottom', fontsize=9, fontweight='bold')
        ax.text(i + w/2, r + 0.3, f'{r:.1f}', ha='center', va='bottom', fontsize=9, fontweight='bold')
        y_top = max(b, r) + 1.5
        ax.annotate(f'↓{imp:.1f}%', xy=(i, y_top), ha='center', fontsize=11,
                    fontweight='bold', color='#2d6a4f')

    ax.set_ylabel('Mean Absolute Error (MAE)', fontsize=12)
    ax.set_title('RAG vs Baseline: MAE Comparison by Nutrient', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels([LABELS_EN[n] for n in NUTRIENTS], fontsize=11)
    ax.legend(fontsize=11)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, '1_mae_comparison.png'), dpi=200)
    plt.close(fig)
    print('✓ 1_mae_comparison.png')


# ═══════════════════════════════════════════════════════════
# 圖 2：每種食物的熱量誤差散佈圖
# ═══════════════════════════════════════════════════════════
def plot_calorie_scatter():
    fig, ax = plt.subplots(figsize=(12, 6))
    df['bl_cal_err'] = (df['baseline_calories'] - df['gt_calories']).abs()
    df['rag_cal_err'] = (df['rag_calories'] - df['gt_calories']).abs()

    idx = np.arange(len(df))
    ax.scatter(idx, df['bl_cal_err'], color=COLORS['baseline'], alpha=0.7, s=50,
               label='Baseline Error', zorder=3, edgecolors='white', linewidth=0.5)
    ax.scatter(idx, df['rag_cal_err'], color=COLORS['rag'], alpha=0.7, s=50,
               label='RAG Error', zorder=3, edgecolors='white', linewidth=0.5)

    ax.set_xlabel('Food Index', fontsize=11)
    ax.set_ylabel('Calorie Absolute Error (kcal)', fontsize=11)
    ax.set_title('Per-Food Calorie Estimation Absolute Error', fontsize=14, fontweight='bold')
    ax.legend(fontsize=11)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, '2_calorie_error_scatter.png'), dpi=200)
    plt.close(fig)
    print('✓ 2_calorie_error_scatter.png')


# ═══════════════════════════════════════════════════════════
# 圖 3：改善百分比雷達圖
# ═══════════════════════════════════════════════════════════
def plot_radar():
    labels = [LABELS_EN[n] for n in NUTRIENTS]
    values = summary['improvement_mae_pct'].values.tolist()
    values_closed = values + [values[0]]

    angles = np.linspace(0, 2 * np.pi, len(labels), endpoint=False).tolist()
    angles += angles[:1]

    fig, ax = plt.subplots(figsize=(7, 7), subplot_kw=dict(polar=True))
    ax.fill(angles, values_closed, color=COLORS['rag'], alpha=0.25)
    ax.plot(angles, values_closed, color=COLORS['rag'], linewidth=2)

    for angle, val in zip(angles[:-1], values):
        ax.text(angle, val + 5, f'{val:.1f}%', ha='center', fontsize=11, fontweight='bold')

    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(labels, fontsize=11)
    ax.set_ylim(0, 100)
    ax.set_title('RAG MAE Improvement Rate (%) by Nutrient', fontsize=14, fontweight='bold', pad=20)
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, '3_improvement_radar.png'), dpi=200)
    plt.close(fig)
    print('✓ 3_improvement_radar.png')


# ═══════════════════════════════════════════════════════════
# 圖 4：各食物類別的熱量 MAE 對比
# ═══════════════════════════════════════════════════════════
def plot_category_mae():
    df['bl_cal_err'] = (df['baseline_calories'] - df['gt_calories']).abs()
    df['rag_cal_err'] = (df['rag_calories'] - df['gt_calories']).abs()
    cat_mae = df.groupby('category')[['bl_cal_err', 'rag_cal_err']].mean().sort_values('bl_cal_err', ascending=True)

    fig, ax = plt.subplots(figsize=(10, 7))
    y = np.arange(len(cat_mae))
    h = 0.35
    ax.barh(y + h/2, cat_mae['bl_cal_err'], h, label='Baseline', color=COLORS['baseline'], edgecolor='white')
    ax.barh(y - h/2, cat_mae['rag_cal_err'], h, label='RAG', color=COLORS['rag'], edgecolor='white')

    ax.set_yticks(y)
    ax.set_yticklabels(cat_mae.index, fontsize=10)
    ax.set_xlabel('Mean Calorie Absolute Error (kcal)', fontsize=11)
    ax.set_title('Calorie MAE by Food Category', fontsize=14, fontweight='bold')
    ax.legend(fontsize=11)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, '4_category_calorie_mae.png'), dpi=200)
    plt.close(fig)
    print('✓ 4_category_calorie_mae.png')


# ═══════════════════════════════════════════════════════════
# 圖 5：Baseline vs RAG 熱量預測值 vs 真實值（雙軸散佈）
# ═══════════════════════════════════════════════════════════
def plot_predicted_vs_actual():
    fig, axes = plt.subplots(1, 2, figsize=(13, 6))

    for ax_i, (method, col, color, title) in enumerate([
        ('Baseline', 'baseline_calories', COLORS['baseline'], 'Baseline: Predicted vs Actual'),
        ('RAG', 'rag_calories', COLORS['rag'], 'RAG: Predicted vs Actual'),
    ]):
        ax = axes[ax_i]
        gt = df['gt_calories']
        pred = df[col]
        ax.scatter(gt, pred, color=color, alpha=0.7, s=50, edgecolors='white', linewidth=0.5)
        lims = [0, max(gt.max(), pred.max()) * 1.1]
        ax.plot(lims, lims, 'k--', alpha=0.4, linewidth=1, label='Perfect prediction')
        ax.set_xlim(lims)
        ax.set_ylim(lims)
        ax.set_xlabel('Actual Calories (kcal)', fontsize=11)
        ax.set_ylabel('Predicted Calories (kcal)', fontsize=11)
        ax.set_title(title, fontsize=13, fontweight='bold')
        ax.legend(fontsize=10)
        ax.set_aspect('equal')
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)

    fig.suptitle('Calorie Predicted vs Actual', fontsize=14, fontweight='bold', y=1.02)
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, '5_predicted_vs_actual.png'), dpi=200, bbox_inches='tight')
    plt.close(fig)
    print('✓ 5_predicted_vs_actual.png')


# ═══════════════════════════════════════════════════════════
# 圖 6：四種營養素的誤差箱型圖
# ═══════════════════════════════════════════════════════════
def plot_error_boxplot():
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))

    for i, nut in enumerate(NUTRIENTS):
        ax = axes[i // 2][i % 2]
        bl_err = (df[f'baseline_{nut}'] - df[f'gt_{nut}']).abs()
        rag_err = (df[f'rag_{nut}'] - df[f'gt_{nut}']).abs()

        bp = ax.boxplot([bl_err, rag_err], tick_labels=['Baseline', 'RAG'], patch_artist=True,
                        widths=0.5, medianprops=dict(color='black', linewidth=1.5))
        bp['boxes'][0].set_facecolor(COLORS['baseline'])
        bp['boxes'][1].set_facecolor(COLORS['rag'])
        for box in bp['boxes']:
            box.set_alpha(0.7)

        ax.set_ylabel('Absolute Error', fontsize=11)
        ax.set_title(LABELS_EN[nut], fontsize=12, fontweight='bold')
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)

    fig.suptitle('Error Distribution by Nutrient (Box Plot)', fontsize=14, fontweight='bold')
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(os.path.join(out_dir, '6_error_boxplot.png'), dpi=200)
    plt.close(fig)
    print('✓ 6_error_boxplot.png')


# ═══════════════════════════════════════════════════════════
# 圖 7：RMSE 對比柱狀圖
# ═══════════════════════════════════════════════════════════
def plot_rmse_comparison():
    fig, ax = plt.subplots(figsize=(10, 6))
    x = np.arange(len(NUTRIENTS))
    w = 0.35
    bl_rmse = summary['baseline_rmse'].values
    rag_rmse = summary['rag_rmse'].values

    ax.bar(x - w/2, bl_rmse, w, label='Baseline', color=COLORS['baseline'], edgecolor='white')
    ax.bar(x + w/2, rag_rmse, w, label='RAG', color=COLORS['rag'], edgecolor='white')

    for i, (b, r) in enumerate(zip(bl_rmse, rag_rmse)):
        ax.text(i - w/2, b + 0.2, f'{b:.1f}', ha='center', va='bottom', fontsize=9, fontweight='bold')
        ax.text(i + w/2, r + 0.2, f'{r:.1f}', ha='center', va='bottom', fontsize=9, fontweight='bold')

    ax.set_ylabel('RMSE', fontsize=12)
    ax.set_title('RAG vs Baseline: RMSE Comparison by Nutrient', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels([LABELS_EN[n] for n in NUTRIENTS], fontsize=11)
    ax.legend(fontsize=11)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, '7_rmse_comparison.png'), dpi=200)
    plt.close(fig)
    print('✓ 7_rmse_comparison.png')


# ═══════════════════════════════════════════════════════════
# 圖 8：熱量誤差分佈直方圖
# ═══════════════════════════════════════════════════════════
def plot_calorie_error_hist():
    fig, ax = plt.subplots(figsize=(10, 6))
    bl_err = df['baseline_calories'] - df['gt_calories']
    rag_err = df['rag_calories'] - df['gt_calories']

    bins = np.linspace(min(bl_err.min(), rag_err.min()) - 5,
                       max(bl_err.max(), rag_err.max()) + 5, 25)
    ax.hist(bl_err, bins=bins, alpha=0.6, color=COLORS['baseline'], label='Baseline', edgecolor='white')
    ax.hist(rag_err, bins=bins, alpha=0.6, color=COLORS['rag'], label='RAG', edgecolor='white')
    ax.axvline(0, color='black', linestyle='--', alpha=0.5, linewidth=1)

    ax.set_xlabel('Calorie Error (Predicted - Actual) kcal', fontsize=11)
    ax.set_ylabel('Number of Foods', fontsize=11)
    ax.set_title('Calorie Prediction Error Distribution', fontsize=14, fontweight='bold')
    ax.legend(fontsize=11)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, '8_calorie_error_histogram.png'), dpi=200)
    plt.close(fig)
    print('✓ 8_calorie_error_histogram.png')


# ═══════════════════════════════════════════════════════════
# 圖 9：綜合改善百分比總覽
# ═══════════════════════════════════════════════════════════
def plot_improvement_summary():
    fig, ax = plt.subplots(figsize=(9, 5))
    labels = [LABELS_EN[n] for n in NUTRIENTS]
    mae_imp = summary['improvement_mae_pct'].values
    colors = ['#2d6a4f' if v > 0 else '#d00000' for v in mae_imp]

    bars = ax.barh(labels, mae_imp, color=colors, edgecolor='white', height=0.5)
    for bar, val in zip(bars, mae_imp):
        x_pos = val + 1 if val > 0 else val - 1
        ax.text(x_pos, bar.get_y() + bar.get_height()/2,
                f'{val:+.1f}%', va='center', fontsize=12, fontweight='bold',
                color='#2d6a4f' if val > 0 else '#d00000')

    ax.axvline(0, color='black', linewidth=0.8)
    ax.set_xlabel('MAE Improvement (%)', fontsize=12)
    ax.set_title('Overall MAE Improvement Rate by RAG Pipeline', fontsize=14, fontweight='bold')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, '9_improvement_summary.png'), dpi=200)
    plt.close(fig)
    print('✓ 9_improvement_summary.png')


# ═══════════════════════════════════════════════════════════
# 執行所有圖表
# ═══════════════════════════════════════════════════════════
if __name__ == '__main__':
    print(f'\nGenerating charts to {out_dir}\n')
    plot_mae_comparison()
    plot_calorie_scatter()
    plot_radar()
    plot_category_mae()
    plot_predicted_vs_actual()
    plot_error_boxplot()
    plot_rmse_comparison()
    plot_calorie_error_hist()
    plot_improvement_summary()
    print(f'\nDone! 9 charts saved to evaluation/charts/')
