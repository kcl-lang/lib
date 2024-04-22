import { execProgram, ExecProgramArgs } from 'kcl-lib'
function main() {
  const result = execProgram(new ExecProgramArgs(['schema.k']))
  console.log(result.yamlResult)
}

main()
