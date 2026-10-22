use crate::{
    features::tasks::{self, Task, TaskSource},
    tasks_store, AppError,
};
use std::path::Path;
/// Account is derived by the bridge from the authenticated Rust session.
/// Demo has a separate namespace and never touches real-account documents.
/// For `add_homework`, `id` is a stable assignment ID (for example `spoc:123`),
/// not a local task ID. Repeated adds return the existing task in the task list.
/// An empty `due` means no deadline; other deadlines are dates or RFC3339 instants.
#[allow(clippy::too_many_arguments)] // Coarse CRUD command mirrors the bridge input.
pub fn edit(
    root: &Path,
    account: &str,
    action: &str,
    id: Option<&str>,
    title: Option<&str>,
    due: Option<&str>,
    completed: Option<bool>,
) -> Result<Vec<Task>, AppError> {
    if root.as_os_str().is_empty() || account.is_empty() {
        return Err(AppError::invalid());
    }
    tasks_store::transact(root, account, |tasks| {
        match action {
            "load" => {}
            "add" | "add_homework" | "update" => {
                let title = title.ok_or_else(AppError::invalid)?.trim();
                let due = due.ok_or_else(AppError::invalid)?;
                tasks::validate(title, due)?;
                let source = if action == "add_homework" {
                    Some(TaskSource::homework(id.ok_or_else(AppError::invalid)?)?)
                } else {
                    None
                };
                // Check under the same storage lock as load/save. Repeated adds
                // must not refresh user edits or reset local completion.
                if source.is_some() && tasks.iter().any(|task| task.source == source) {
                    return Ok(());
                }
                if action != "update" {
                    tasks.push(Task {
                        id: format!("{:032x}", rand::random::<u128>()),
                        title: title.into(),
                        due: due.into(),
                        completed: false,
                        source,
                    });
                } else {
                    let task = tasks
                        .iter_mut()
                        .find(|t| Some(t.id.as_str()) == id)
                        .ok_or_else(AppError::invalid)?;
                    task.title = title.into();
                    task.due = due.into();
                }
            }
            "toggle" => {
                tasks
                    .iter_mut()
                    .find(|t| Some(t.id.as_str()) == id)
                    .ok_or_else(AppError::invalid)?
                    .completed = completed.ok_or_else(AppError::invalid)?;
            }
            "delete" => {
                let id = id.ok_or_else(AppError::invalid)?;
                tasks.retain(|t| t.id != id);
            }
            _ => return Err(AppError::invalid()),
        }
        Ok(())
    })
}

impl<U: super::SessionSource> super::Workspace<U> {
    pub fn edit_tasks(
        &self,
        root: &Path,
        action: &str,
        id: Option<&str>,
        title: Option<&str>,
        due: Option<&str>,
        completed: Option<bool>,
    ) -> Result<Vec<Task>, AppError> {
        edit(
            root,
            &self.upstream.account()?,
            action,
            id,
            title,
            due,
            completed,
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn tasks_persist_crud_isolate_accounts_and_protect_corruption() {
        let root = std::env::temp_dir().join(format!("ginkgo-tasks-{:x}", rand::random::<u64>()));
        let added = edit(
            &root,
            "synthetic-a",
            "add",
            None,
            Some(" 合成待办 "),
            Some("2026-10-20"),
            None,
        )
        .unwrap();
        let id = &added[0].id;
        assert_eq!(added[0].title, "合成待办");
        assert!(edit(&root, "synthetic-b", "load", None, None, None, None)
            .unwrap()
            .is_empty());
        edit(
            &root,
            "synthetic-a",
            "update",
            Some(id),
            Some("修改待办"),
            Some("2026-10-21"),
            None,
        )
        .unwrap();
        assert!(
            edit(
                &root,
                "synthetic-a",
                "toggle",
                Some(id),
                None,
                None,
                Some(true)
            )
            .unwrap()[0]
                .completed
        );
        assert!(
            edit(&root, "synthetic-a", "delete", Some(id), None, None, None)
                .unwrap()
                .is_empty()
        );
        let file = std::fs::read_dir(&root)
            .unwrap()
            .next()
            .unwrap()
            .unwrap()
            .path();
        std::fs::write(&file, b"broken").unwrap();
        assert!(edit(
            &root,
            "synthetic-a",
            "add",
            None,
            Some("不得覆盖"),
            Some("2026-10-20"),
            None
        )
        .is_err());
        assert_eq!(std::fs::read(&file).unwrap(), b"broken");
        std::fs::remove_dir_all(root).unwrap();
    }
}
