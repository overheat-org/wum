import fs from "fs";
import { program } from "commander";

program
    .name("wum")
    .description("The wum CLI")

const commandFiles = fs.readdirSync(__dirname + "/commands")

for(const fileName of commandFiles) {
    import(__dirname + "/commands/" + fileName);
}
