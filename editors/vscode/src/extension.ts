import * as vscode from 'vscode';
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  TransportKind
} from 'vscode-languageclient/node';

let client: LanguageClient | undefined;

export function activate(context: vscode.ExtensionContext): void {
  const config = vscode.workspace.getConfiguration('nucleor');
  const serverPath = config.get<string>('lspServerPath', 'nucleor-lsp.exe');

  const serverOptions: ServerOptions = {
    command: serverPath,
    transport: TransportKind.stdio
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ scheme: 'file', language: 'nucleor' }],
    synchronize: {
      fileEvents: vscode.workspace.createFileSystemWatcher('**/*.nr')
    }
  };

  client = new LanguageClient(
    'nucleor-lsp',
    'Nucleor Language Server',
    serverOptions,
    clientOptions
  );

  client.start();
  context.subscriptions.push({ dispose: () => client?.stop() });
}

export function deactivate(): Thenable<void> | undefined {
  return client?.stop();
}
