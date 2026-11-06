// modules/org/components/OrgTreeExplorer.tsx
"use client";

import { useMemo, useState, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { displayName, type Locale } from "@/lib/i18n";
import {
  PERM_ORG_UNIT_WRITE,
  PERM_POS_UNIT_WRITE,
  usePermissions,
  type PermissionTarget,
} from "@/modules/org/permissions";
import type {
  CompanyLevelRule,
  HierarchyLevel,
  TreeKind,
  UnitRow,
} from "@/modules/org/types";
import { childLevelRules, departmentIdOf, moveTargets } from "@/modules/org/unitTree";
import { UnitActionDialog, type UnitAction } from "./UnitActionDialog";

/** Turns on the add, rename, move and close buttons. Leave it out for a read-only tree. */
export interface TreeManageOptions {
  tree: TreeKind;
  companyId: number;
  levels: HierarchyLevel[];
  /** The selected company's open rules. */
  rules: CompanyLevelRule[];
}

interface OrgTreeExplorerProps {
  title: string;
  description: string;
  emptyText: string;
  units: UnitRow[];
  locale: Locale;
  manage?: TreeManageOptions;
}

interface TreeNodeProps {
  unit: UnitRow;
  childrenOf: Map<number | null, UnitRow[]>;
  expanded: Set<number>;
  onToggle: (id: number) => void;
  locale: Locale;
  renderActions: (unit: UnitRow) => ReactNode;
}

interface OpenDialog {
  action: UnitAction;
  unit: UnitRow | null;
  parent: UnitRow | null;
}

/**
 * Where the permission is checked for a unit (see HRIS_ORG_FRONTEND_REFERENCE.md, 8.2).
 * Org tree: the unit. Position tree: the unit's Department. A Department itself,
 * and a new top-level unit, need a company-wide or tenant-wide role (empty target).
 */
function selfTarget(tree: TreeKind, units: UnitRow[], u: UnitRow): PermissionTarget {
  if (tree === "org") return { orgUnitId: u.unit_id };
  return u.parent_unit_id === null ? {} : { departmentId: departmentIdOf(units, u.unit_id) };
}

/** Where the permission is checked for adding a unit under `u`. */
function createTarget(tree: TreeKind, units: UnitRow[], u: UnitRow): PermissionTarget {
  if (tree === "org") return { orgUnitId: u.unit_id };
  return { departmentId: departmentIdOf(units, u.unit_id) };
}

const actionButtonClass =
  "rounded border border-zinc-300 bg-white px-2 py-0.5 text-xs font-medium text-zinc-700 hover:bg-zinc-50";

function TreeNode({ unit, childrenOf, expanded, onToggle, locale, renderActions }: TreeNodeProps) {
  const kids = childrenOf.get(unit.unit_id) ?? [];
  const isOpen = expanded.has(unit.unit_id);

  return (
    <li>
      <div className="flex flex-wrap items-center gap-2 py-1">
        {kids.length > 0 ? (
          <button
            type="button"
            aria-expanded={isOpen}
            onClick={() => onToggle(unit.unit_id)}
            className="w-5 text-zinc-500 hover:text-zinc-900"
          >
            {isOpen ? "▾" : "▸"}
          </button>
        ) : (
          <span className="inline-block w-5" />
        )}
        <span className="text-sm font-medium text-zinc-900">
          {displayName(locale, unit.name_en, unit.name_km)}
        </span>
        <span className="rounded bg-zinc-100 px-1.5 py-0.5 text-xs text-zinc-700">
          {displayName(locale, unit.level_name_en, unit.level_name_km)}
        </span>
        {kids.length > 0 && (
          <span className="text-xs text-zinc-400">{kids.length} under</span>
        )}
        <span className="text-xs text-zinc-400">since {unit.valid_from}</span>
        {renderActions(unit)}
      </div>
      {kids.length > 0 && isOpen && (
        <ul className="ml-2.5 border-l border-zinc-200 pl-3">
          {kids.map((kid) => (
            <TreeNode
              key={kid.unit_id}
              unit={kid}
              childrenOf={childrenOf}
              expanded={expanded}
              onToggle={onToggle}
              locale={locale}
              renderActions={renderActions}
            />
          ))}
        </ul>
      )}
    </li>
  );
}

/**
 * Expandable tree of open units. Works for both the org tree and the position tree.
 * With `manage`, each unit gets add, rename, move and close buttons, shown only where
 * the user is allowed (check_permissions). The database checks every write again.
 * Give it a `key` that includes the company id so the open/closed state resets on company change.
 */
export function OrgTreeExplorer({
  title,
  description,
  emptyText,
  units,
  locale,
  manage,
}: OrgTreeExplorerProps) {
  const router = useRouter();
  const { roots, childrenOf, branchIds } = useMemo(() => {
    const map = new Map<number | null, UnitRow[]>();
    for (const u of units) {
      const list = map.get(u.parent_unit_id);
      if (list) list.push(u);
      else map.set(u.parent_unit_id, [u]);
    }
    for (const list of map.values()) {
      list.sort((a, b) => a.level_rank - b.level_rank || a.name_en.localeCompare(b.name_en));
    }
    return {
      roots: map.get(null) ?? [],
      childrenOf: map,
      branchIds: [...map.keys()].filter((k): k is number => k !== null),
    };
  }, [units]);

  const [expanded, setExpanded] = useState<Set<number>>(
    () => new Set(roots.map((r) => r.unit_id))
  );
  const [dialog, setDialog] = useState<OpenDialog | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  // One batched permission check for every unit on the screen.
  const tree = manage?.tree;
  const permissionTargets = useMemo(() => {
    if (!tree) return [];
    const list: PermissionTarget[] = [{}]; // adding a top-level unit
    for (const u of units) {
      list.push(selfTarget(tree, units, u));
      list.push(createTarget(tree, units, u));
    }
    return list;
  }, [tree, units]);
  const permission = usePermissions(
    manage?.companyId ?? 0,
    tree === "pos" ? PERM_POS_UNIT_WRITE : PERM_ORG_UNIT_WRITE,
    permissionTargets
  );

  function toggle(id: number) {
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function openDialog(next: OpenDialog) {
    setNotice(null);
    setDialog(next);
  }

  function handleDone(message: string) {
    const parent = dialog?.action === "create" ? dialog.parent : null;
    if (parent) setExpanded((prev) => new Set(prev).add(parent.unit_id));
    setDialog(null);
    setNotice(message);
    router.refresh(); // reload units from the database
  }

  function renderActions(u: UnitRow): ReactNode {
    if (!manage) return null;

    const self = selfTarget(manage.tree, units, u);
    const canSelf = permission.can(self.orgUnitId, self.departmentId);
    const under = createTarget(manage.tree, units, u);
    const canAdd =
      permission.can(under.orgUnitId, under.departmentId) &&
      childLevelRules(manage.tree, u, manage.rules).length > 0;

    let canMove = false;
    if (canSelf) {
      const t = moveTargets(manage.tree, u, units, manage.rules);
      canMove = t.rootAllowed || t.parents.length > 0;
    }

    if (!canAdd && !canSelf) return null;

    return (
      <span className="ml-auto flex items-center gap-1.5">
        {canAdd && (
          <button
            type="button"
            onClick={() => openDialog({ action: "create", unit: null, parent: u })}
            className={actionButtonClass}
          >
            Add
          </button>
        )}
        {canSelf && (
          <button
            type="button"
            onClick={() => openDialog({ action: "rename", unit: u, parent: null })}
            className={actionButtonClass}
          >
            Rename
          </button>
        )}
        {canMove && (
          <button
            type="button"
            onClick={() => openDialog({ action: "move", unit: u, parent: null })}
            className={actionButtonClass}
          >
            Move
          </button>
        )}
        {canSelf && (
          <button
            type="button"
            onClick={() => openDialog({ action: "close", unit: u, parent: null })}
            className="rounded border border-zinc-300 bg-white px-2 py-0.5 text-xs font-medium text-red-700 hover:bg-red-50"
          >
            Close
          </button>
        )}
      </span>
    );
  }

  const canAddTop =
    manage !== undefined &&
    permission.can(undefined, undefined) &&
    childLevelRules(manage.tree, null, manage.rules).length > 0;

  return (
    <section className="rounded-lg border border-zinc-200 bg-white shadow-sm">
      <div className="flex flex-wrap items-start justify-between gap-3 border-b border-zinc-200 px-4 py-3">
        <div>
          <h2 className="text-base font-semibold text-zinc-900">{title}</h2>
          <p className="mt-0.5 text-sm text-zinc-600">{description}</p>
        </div>
        <div className="flex items-center gap-2 text-xs">
          {canAddTop && (
            <button
              type="button"
              onClick={() => openDialog({ action: "create", unit: null, parent: null })}
              className="rounded-md bg-zinc-900 px-2.5 py-1 font-medium text-white hover:bg-zinc-800"
            >
              Add top-level unit
            </button>
          )}
          {units.length > 0 && (
            <>
              <span className="text-zinc-500">{units.length} open units</span>
              <button
                type="button"
                onClick={() => setExpanded(new Set(branchIds))}
                className="rounded-md border border-zinc-300 px-2.5 py-1 font-medium text-zinc-700 hover:bg-zinc-50"
              >
                Expand all
              </button>
              <button
                type="button"
                onClick={() => setExpanded(new Set())}
                className="rounded-md border border-zinc-300 px-2.5 py-1 font-medium text-zinc-700 hover:bg-zinc-50"
              >
                Collapse all
              </button>
            </>
          )}
        </div>
      </div>

      {notice && (
        <p
          role="status"
          className="mx-4 mt-4 rounded-md bg-emerald-50 px-3 py-2 text-sm text-emerald-800"
        >
          {notice}
        </p>
      )}

      <div className="p-4">
        {units.length === 0 ? (
          <p className="rounded-md bg-zinc-100 px-3 py-2 text-sm text-zinc-700">
            {emptyText}
          </p>
        ) : (
          <ul>
            {roots.map((root) => (
              <TreeNode
                key={root.unit_id}
                unit={root}
                childrenOf={childrenOf}
                expanded={expanded}
                onToggle={toggle}
                locale={locale}
                renderActions={renderActions}
              />
            ))}
          </ul>
        )}
      </div>

      {dialog && manage && (
        <UnitActionDialog
          key={`${dialog.action}-${dialog.unit?.unit_id ?? "new"}-${dialog.parent?.unit_id ?? "top"}`}
          tree={manage.tree}
          companyId={manage.companyId}
          levels={manage.levels}
          rules={manage.rules}
          units={units}
          locale={locale}
          action={dialog.action}
          unit={dialog.unit}
          parent={dialog.parent}
          onCancel={() => setDialog(null)}
          onDone={handleDone}
        />
      )}
    </section>
  );
}