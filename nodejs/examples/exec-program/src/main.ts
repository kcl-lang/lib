import { execProgram, ExecProgramArgs } from '@kcl-lib/native'
function main() {
  const result = execProgram(new ExecProgramArgs(['schema.k']))
  console.log(result.yamlResult)
}

main()
