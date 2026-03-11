import { program } from "commander";

program
    .command("add")
    .description("Install wum package")
    .argument("<string>", "Name of wum package")
    .action(handleAdd)

program
    .command("remove")
    .description("Uninstall wum package")
    .argument("<string>", "")
    .action(handleRemove)

function handleAdd() {}

function handleRemove() {}
