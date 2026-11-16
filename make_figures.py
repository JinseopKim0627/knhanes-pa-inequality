import csv, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

plt.rcParams.update({"font.family": "Liberation Sans", "font.size": 11})
rows = list(csv.DictReader(open(sys.argv[1])))
OUT = sys.argv[2]

CATS = [  # outcome, label, color, marker, linestyle, markersize
    ("Y_NEITHER", "Neither", "#E69F00", "o", "-", 9),
    ("Y_AERONLY", "Aerobic only", "#56B4E9", "^", (0, (1, 1.6)), 10),
    ("Y_STRONLY", "Muscle-strengthening only", "#009E73", "s", (0, (4, 2)), 8.5),
    ("Y_BOTH", "Both guidelines", "#CC79A7", "D", (0, (8, 3)), 7),
]
LEVELS = {
    "age10": ["20-29", "30-39", "40-49", "50-59", "60-69", "70-79", "80+"],
    "edu": ["Elementary", "Middle", "High", "College+"],
    "inc": ["Low", "Mid-Low", "Mid-High", "High"],
}


def get(spec, sex, factor):
    d = {}
    for r in rows:
        if r["Spec"] == spec and r["Sex"] == sex and r["factor"] == factor and r["level"] != "Missing":
            d[(r["Outcome"], r["level"])] = (float(r["est"]), float(r["lcl"]), float(r["ucl"]))
    return d


def style_ax(ax, ymax, ylabels=True):
    ax.set_ylim(0, ymax)
    ax.set_yticks(range(0, ymax + 1, 10))
    ax.set_yticklabels([f"{t}%" for t in range(0, ymax + 1, 10)])
    if not ylabels: ax.tick_params(labelleft=False)
    ax.grid(axis="y", color="#E5E5E5", lw=0.8)
    ax.set_axisbelow(True)
    for s in ax.spines.values():
        s.set_color("#333333"); s.set_linewidth(1.0)
    ax.tick_params(colors="#4D4D4D", labelsize=11, length=4)


def draw(ax, d, levels):
    x = list(range(len(levels)))
    for o, lab, c, m, ls, ms in CATS:
        e = [d[(o, l)][0] for l in levels]
        lo = [d[(o, l)][0] - d[(o, l)][1] for l in levels]
        hi = [d[(o, l)][2] - d[(o, l)][0] for l in levels]
        ax.errorbar(x, e, yerr=[lo, hi], fmt="none", ecolor=c, elinewidth=1.1, capsize=4, capthick=1.1, zorder=2)
        ax.plot(x, e, color=c, ls=ls, lw=1.8, zorder=3)
        ax.plot(x, e, color=c, marker=m, ms=ms, ls="none", zorder=4)
    ax.set_xticks(x); ax.set_xticklabels(levels)
    ax.set_xlim(-0.55, len(levels) - 0.45)


from matplotlib.patches import Rectangle
def strip(ax, text, side="top", h=0.085):
    if side == "top":
        ax.add_patch(Rectangle((0, 1), 1, h, transform=ax.transAxes, fc="white", ec="#333333", lw=1.0, clip_on=False))
        ax.text(0.5, 1 + h / 2, text, transform=ax.transAxes, ha="center", va="center", fontsize=12, fontweight="bold")
    else:
        w = h * ax.bbox.height / ax.bbox.width
        ax.add_patch(Rectangle((1, 0), w, 1, transform=ax.transAxes, fc="white", ec="#333333", lw=1.0, clip_on=False))
        ax.text(1 + w / 2, 0.5, text, transform=ax.transAxes, ha="center", va="center", rotation=-90, fontsize=12,
                fontweight="bold")


def legend(fig, y):
    h = [Line2D([0], [0], color=c, ls=ls, lw=1.8, marker=m, ms=ms) for o, lab, c, m, ls, ms in CATS]
    fig.legend(h, [c[1] for c in CATS], loc="upper center", ncol=4, frameon=False, bbox_to_anchor=(0.5, y),
               fontsize=11.5, handlelength=3.6, columnspacing=2.2)


def age_fig(spec, ymax, fname):
    fig, axes = plt.subplots(1, 2, figsize=(9.2, 5.2), sharey=True)
    for i, (ax, sex) in enumerate(zip(axes, ["Male", "Female"])):
        draw(ax, get(spec, sex, "age10"), LEVELS["age10"])
        style_ax(ax, ymax, i == 0)
        strip(ax, sex, "top")
    axes[0].set_ylabel("Adjusted predicted probability (%)", fontsize=12.5)
    fig.supxlabel("Age group (years)", fontsize=12.5, y=0.03)
    legend(fig, 0.995)
    fig.subplots_adjust(left=0.08, right=0.985, top=0.80, bottom=0.15, wspace=0.05)
    fig.savefig(f"{OUT}/{fname}", dpi=400)
    plt.close(fig)


def ses_fig(spec, fname):
    fig, axes = plt.subplots(2, 2, figsize=(10.5, 7.2), sharey=True)
    for r, sex in enumerate(["Male", "Female"]):
        for c, fac in enumerate(["edu", "inc"]):
            ax = axes[r, c]
            draw(ax, get(spec, sex, fac), LEVELS[fac])
            style_ax(ax, 70, c == 0)
            if r == 0:
                ax.set_xticklabels([])
                strip(ax, ["Education", "Household income"][c], "top", 0.1)
            else:
                plt.setp(ax.get_xticklabels(), rotation=25, ha="right")
            if c == 1:
                strip(ax, sex, "right")
    fig.supylabel("Adjusted predicted probability (%)", fontsize=12.5, x=0.01)
    fig.supxlabel("Educational attainment  |  Household income quartile", fontsize=12.5, y=0.015)
    legend(fig, 0.995)
    fig.subplots_adjust(left=0.08, right=0.95, top=0.86, bottom=0.14, wspace=0.05, hspace=0.06)
    fig.savefig(f"{OUT}/{fname}", dpi=400)
    plt.close(fig)


age_fig("MAIN", 80, "Figure1.png")
ses_fig("MAIN", "Figure2.png")
age_fig("NOCOVID", 80, "FigureS1.png")
age_fig("LEIS", 90, "FigureS2.png")


def domain_fig(fname):
    """Figure 3: total vs leisure-time aerobic definition, neither and both groups."""
    series = [  # spec, outcome, label, color, marker, linestyle, filled
        ("MAIN", "Y_NEITHER", "Neither — total activity", "#C8553D", "o", "-", True),
        ("LEIS", "Y_NEITHER", "Neither — leisure-time only", "#C8553D", "o", (0, (4, 2)), False),
        ("MAIN", "Y_BOTH", "Both — total activity", "#2E4057", "D", "-", True),
        ("LEIS", "Y_BOTH", "Both — leisure-time only", "#2E4057", "D", (0, (4, 2)), False),
    ]
    fig, axes = plt.subplots(2, 2, figsize=(10.5, 7.2), sharey=True)
    for r, sex in enumerate(["Male", "Female"]):
        for c, fac in enumerate(["edu", "inc"]):
            ax = axes[r, c]
            levels = LEVELS[fac]
            x = list(range(len(levels)))
            for spec, out, lab, col, mk, ls, filled in series:
                d = get(spec, sex, fac)
                e = [d[(out, l)][0] for l in levels]
                lo = [d[(out, l)][0] - d[(out, l)][1] for l in levels]
                hi = [d[(out, l)][2] - d[(out, l)][0] for l in levels]
                ax.errorbar(x, e, yerr=[lo, hi], fmt="none", ecolor=col, elinewidth=1.1, capsize=4, zorder=2)
                ax.plot(x, e, color=col, ls=ls, lw=1.8, zorder=3)
                ax.plot(x, e, color=col, marker=mk, ms=8, ls="none", zorder=4,
                        mfc=col if filled else "white", mec=col, mew=1.6)
            ax.set_xticks(x); ax.set_xticklabels(levels); ax.set_xlim(-0.55, len(levels) - 0.45)
            style_ax(ax, 90, c == 0)
            if r == 0:
                ax.set_xticklabels([])
                strip(ax, ["Education", "Household income"][c], "top", 0.1)
            else:
                plt.setp(ax.get_xticklabels(), rotation=25, ha="right")
            if c == 1:
                strip(ax, sex, "right")
    h = [Line2D([0], [0], color=col, ls=ls, lw=1.8, marker=mk, ms=8, mfc=col if f else "white", mec=col, mew=1.6)
         for _, _, _, col, mk, ls, f in series]
    fig.legend(h, [s[2] for s in series], loc="upper center", ncol=2, frameon=False, bbox_to_anchor=(0.5, 0.995),
               fontsize=11.5, handlelength=3.6, columnspacing=2.5)
    fig.supylabel("Adjusted predicted probability (%)", fontsize=12.5, x=0.01)
    fig.supxlabel("Educational attainment  |  Household income quartile", fontsize=12.5, y=0.015)
    fig.subplots_adjust(left=0.08, right=0.95, top=0.84, bottom=0.14, wspace=0.05, hspace=0.06)
    fig.savefig(f"{OUT}/{fname}", dpi=400)
    plt.close(fig)


domain_fig("Figure3.png")
