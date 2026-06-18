-- ==============================================================================
-- CONFIGURAÇÃO INICIAL DO ENTITY FRAMEWORK
-- ==============================================================================
-- Verifica se a tabela de controle interna do EF Core já existe no banco.
IF OBJECT_ID(N'[__EFMigrationsHistory]') IS NULL
BEGIN
    -- Se não existir, cria a tabela. Ela guarda quais migrações já rodaram, 
    -- evitando que o script tente criar as mesmas tabelas duas vezes.
    CREATE TABLE [__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END;
GO

-- ==============================================================================
-- MIGRAÇÃO 1: InitialCreate (Criação do núcleo do sistema)
-- ==============================================================================
BEGIN TRANSACTION;

-- Criação da entidade forte: Trilha
CREATE TABLE [Trails] (
    -- uniqueidentifier é o equivalente SQL ao tipo Guid (UUID) do C#
    [Id] uniqueidentifier NOT NULL,
    [Name] nvarchar(256) NOT NULL,
    -- nvarchar(max) permite textos longos sem limite fixo de caracteres (equivalente ao antigo TEXT)
    [Description] nvarchar(max) NOT NULL,
    -- datetime2 é mais preciso e tem maior range de datas que o datetime padrão
    [CreatedAt] datetime2 NOT NULL,
    -- Define a chave primária (PK) da tabela
    CONSTRAINT [PK_Trails] PRIMARY KEY ([Id])
);

-- Criação da entidade forte: Usuário
CREATE TABLE [Users] (
    [Id] uniqueidentifier NOT NULL,
    [Name] nvarchar(256) NOT NULL,
    [Email] nvarchar(256) NOT NULL,
    [PasswordHash] nvarchar(max) NOT NULL,
    [Role] nvarchar(max) NOT NULL,
    [CreatedAt] datetime2 NOT NULL,
    CONSTRAINT [PK_Users] PRIMARY KEY ([Id])
);

-- Criação da entidade dependente: Desafio (Aula/Módulo)
CREATE TABLE [Challenges] (
    [Id] uniqueidentifier NOT NULL,
    -- Chave Estrangeira (FK) apontando para a Trilha (Relacionamento 1:N)
    [TrailId] uniqueidentifier NOT NULL,
    [Title] nvarchar(256) NOT NULL,
    [Description] nvarchar(max) NOT NULL,
    [Order] int NOT NULL,
    [CreatedAt] datetime2 NOT NULL,
    CONSTRAINT [PK_Challenges] PRIMARY KEY ([Id]),
    -- Cria a restrição de FK. 'ON DELETE CASCADE' significa que, se a Trilha for apagada,
    -- todos os Desafios vinculados a ela serão apagados automaticamente pelo banco.
    CONSTRAINT [FK_Challenges_Trails_TrailId] FOREIGN KEY ([TrailId]) REFERENCES [Trails] ([Id]) ON DELETE CASCADE
);

-- Criação da entidade de transação: Submissão
CREATE TABLE [Submissions] (
    [Id] uniqueidentifier NOT NULL,
    [StudentId] uniqueidentifier NOT NULL,
    [ChallengeId] uniqueidentifier NOT NULL,
    [DeliveryUrl] nvarchar(max) NOT NULL,
    [SubmittedAt] datetime2 NOT NULL,
    [Status] nvarchar(max) NOT NULL,
    -- Pode ser NULL, pois uma submissão pode ainda não ter sido revisada
    [ReviewerId] uniqueidentifier NULL,
    [Score] int NULL,
    [Feedback] nvarchar(max) NULL,
    [ReviewedAt] datetime2 NULL,
    CONSTRAINT [PK_Submissions] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_Submissions_Challenges_ChallengeId] FOREIGN KEY ([ChallengeId]) REFERENCES [Challenges] ([Id]) ON DELETE CASCADE,
    -- 'ON DELETE NO ACTION' impede que um usuário seja apagado se ele for revisor ou estudante de uma submissão.
    -- Isso evita a perda de histórico escolar.
    CONSTRAINT [FK_Submissions_Users_ReviewerId] FOREIGN KEY ([ReviewerId]) REFERENCES [Users] ([Id]) ON DELETE NO ACTION,
    CONSTRAINT [FK_Submissions_Users_StudentId] FOREIGN KEY ([StudentId]) REFERENCES [Users] ([Id]) ON DELETE NO ACTION
);

-- Criação de Índices para melhorar a performance de consultas (buscas via FKs)
CREATE INDEX [IX_Challenges_TrailId] ON [Challenges] ([TrailId]);
CREATE INDEX [IX_Submissions_ChallengeId] ON [Submissions] ([ChallengeId]);
CREATE INDEX [IX_Submissions_ReviewerId] ON [Submissions] ([ReviewerId]);
CREATE INDEX [IX_Submissions_StudentId] ON [Submissions] ([StudentId]);

-- Cria um índice ÚNICO no email. Garante no banco que dois usuários não tenham o mesmo email.
CREATE UNIQUE INDEX [IX_Users_Email] ON [Users] ([Email]);

-- Registra que essa migração foi executada com sucesso
INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20260410041722_InitialCreate', N'10.0.5');

COMMIT;
GO

-- ==============================================================================
-- MIGRAÇÃO 2: SharedBaseFoundation (Ajustes e novas tabelas auxiliares)
-- ==============================================================================
BEGIN TRANSACTION;

-- [PADRÃO EF CORE PARA ALTERAR COLUNAS NO SQL SERVER]
-- O SQL Server não deixa alterar uma coluna se ela tiver restrições "Default" atreladas.
-- Esse bloco obscuro de DECLARE @var procura restrições vinculadas à coluna 'Feedback',
-- apaga a restrição se existir, e então altera o tipo da coluna para nvarchar(4000).
DECLARE @var nvarchar(max);
SELECT @var = QUOTENAME([d].[name])
FROM [sys].[default_constraints] [d]
INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
WHERE ([d].[parent_object_id] = OBJECT_ID(N'[Submissions]') AND [c].[name] = N'Feedback');
IF @var IS NOT NULL EXEC(N'ALTER TABLE [Submissions] DROP CONSTRAINT ' + @var + ';');
ALTER TABLE [Submissions] ALTER COLUMN [Feedback] nvarchar(4000) NULL;

-- Repete o mesmo processo para limitar a URL a 2048 caracteres (boa prática para URLs)
DECLARE @var1 nvarchar(max);
SELECT @var1 = QUOTENAME([d].[name])
FROM [sys].[default_constraints] [d]
INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
WHERE ([d].[parent_object_id] = OBJECT_ID(N'[Submissions]') AND [c].[name] = N'DeliveryUrl');
IF @var1 IS NOT NULL EXEC(N'ALTER TABLE [Submissions] DROP CONSTRAINT ' + @var1 + ';');
ALTER TABLE [Submissions] ALTER COLUMN [DeliveryUrl] nvarchar(2048) NOT NULL;

-- Tabela para controle de sessão/segurança (JWT)
CREATE TABLE [RefreshTokens] (
    [Id] uniqueidentifier NOT NULL,
    [UserId] uniqueidentifier NOT NULL,
    [TokenHash] nvarchar(128) NOT NULL,
    [ExpiresAt] datetime2 NOT NULL,
    [CreatedAt] datetime2 NOT NULL,
    [RevokedAt] datetime2 NULL,
    [ReplacedByTokenHash] nvarchar(128) NULL,
    CONSTRAINT [PK_RefreshTokens] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_RefreshTokens_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
);

-- Tabela Associativa: Resolve a relação N:N (Muitos-para-Muitos) entre Usuário e Trilha
CREATE TABLE [TrailEnrollments] (
    [Id] uniqueidentifier NOT NULL,
    [UserId] uniqueidentifier NOT NULL,
    [TrailId] uniqueidentifier NOT NULL,
    [EnrolledAt] datetime2 NOT NULL,
    [CompletedAt] datetime2 NULL,
    CONSTRAINT [PK_TrailEnrollments] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_TrailEnrollments_Trails_TrailId] FOREIGN KEY ([TrailId]) REFERENCES [Trails] ([Id]) ON DELETE CASCADE,
    CONSTRAINT [FK_TrailEnrollments_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
);

-- Tabela para registrar o tempo e ações do usuário
CREATE TABLE [UserActivities] (
    [Id] uniqueidentifier NOT NULL,
    [UserId] uniqueidentifier NOT NULL,
    [ActivityType] nvarchar(64) NOT NULL,
    [TargetType] nvarchar(64) NULL,
    [TargetId] nvarchar(128) NULL,
    [Minutes] int NOT NULL,
    [OccurredAt] datetime2 NOT NULL,
    [CreatedAt] datetime2 NOT NULL,
    CONSTRAINT [PK_UserActivities] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_UserActivities_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
);

-- Configurações do usuário. Relacionamento 1:1.
CREATE TABLE [UserSettings] (
    [Id] uniqueidentifier NOT NULL,
    [UserId] uniqueidentifier NOT NULL,
    [TwoFactorEnabled] bit NOT NULL, -- bit é o equivalente ao booleano (true/false)
    [PublicProfile] bit NOT NULL,
    [EmailNotifications] bit NOT NULL,
    [StudyReminder] bit NOT NULL,
    [AiSuggestions] bit NOT NULL,
    [WeeklyReport] bit NOT NULL,
    [Language] nvarchar(10) NOT NULL,
    [DailyStudyGoal] nvarchar(10) NOT NULL,
    [Autoplay] bit NOT NULL,
    [Subtitles] bit NOT NULL,
    [UpdatedAt] datetime2 NOT NULL,
    CONSTRAINT [PK_UserSettings] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_UserSettings_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
);

-- Índices e restrições de unicidade das novas tabelas
CREATE UNIQUE INDEX [IX_RefreshTokens_TokenHash] ON [RefreshTokens] ([TokenHash]);
CREATE INDEX [IX_RefreshTokens_UserId] ON [RefreshTokens] ([UserId]);
CREATE INDEX [IX_TrailEnrollments_TrailId] ON [TrailEnrollments] ([TrailId]);

-- Garante que um usuário não consiga se matricular duas vezes na mesma trilha
CREATE UNIQUE INDEX [IX_TrailEnrollments_UserId_TrailId] ON [TrailEnrollments] ([UserId], [TrailId]);
-- Índice composto focado em otimizar buscas por data de atividades do usuário
CREATE INDEX [IX_UserActivities_UserId_OccurredAt] ON [UserActivities] ([UserId], [OccurredAt]);
-- Força a regra de 1:1, garantindo que um usuário tenha apenas uma linha de configurações
CREATE UNIQUE INDEX [IX_UserSettings_UserId] ON [UserSettings] ([UserId]);

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20260602183058_SharedBaseFoundation', N'10.0.5');

COMMIT;
GO

-- ==============================================================================
-- MIGRAÇÃO 3: LeanSubmissionModel (Refatoração estrutural e de dados)
-- ==============================================================================
BEGIN TRANSACTION;

-- Rotina do EF para limpar constraints antes de DELETAR a coluna Feedback
DECLARE @var2 nvarchar(max);
SELECT @var2 = QUOTENAME([d].[name])
FROM [sys].[default_constraints] [d]
INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
WHERE ([d].[parent_object_id] = OBJECT_ID(N'[Submissions]') AND [c].[name] = N'Feedback');
IF @var2 IS NOT NULL EXEC(N'ALTER TABLE [Submissions] DROP CONSTRAINT ' + @var2 + ';');
ALTER TABLE [Submissions] DROP COLUMN [Feedback];

-- Rotina do EF para limpar constraints antes de DELETAR a coluna Score
DECLARE @var3 nvarchar(max);
SELECT @var3 = QUOTENAME([d].[name])
FROM [sys].[default_constraints] [d]
INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
WHERE ([d].[parent_object_id] = OBJECT_ID(N'[Submissions]') AND [c].[name] = N'Score');
IF @var3 IS NOT NULL EXEC(N'ALTER TABLE [Submissions] DROP CONSTRAINT ' + @var3 + ';');
ALTER TABLE [Submissions] DROP COLUMN [Score];

-- Renomeia a coluna DeliveryUrl para GitHubUrl (Preserva os dados já existentes)
EXEC sp_rename N'[Submissions].[DeliveryUrl]', N'GitHubUrl', 'COLUMN';

-- Adiciona novas colunas
ALTER TABLE [Submissions] ADD [MentorComment] nvarchar(500) NULL;
ALTER TABLE [Challenges] ADD [YouTubeUrl] nvarchar(2048) NULL;

-- Manipulação de Dados (DML). Atualiza os registros legados para refletir a nova regra de negócio.
UPDATE Submissions SET Status = 'Approved' WHERE Status = 'Reviewed'

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20260604040451_LeanSubmissionModel', N'10.0.5');

COMMIT;
GO

-- ==============================================================================
-- MIGRAÇÃO 4: AddAiFeatures (Integração das features de Inteligência Artificial)
-- ==============================================================================
BEGIN TRANSACTION;

-- Adiciona coluna para motor de busca IA
ALTER TABLE [Challenges] ADD [AiSearchTerms] nvarchar(max) NULL;

-- Criação do perfil de Onboarding (Também relação 1:1 com o Usuário)
CREATE TABLE [OnboardingProfiles] (
    [Id] uniqueidentifier NOT NULL,
    [UserId] uniqueidentifier NOT NULL,
    [TargetRole] nvarchar(256) NOT NULL,
    [TechnicalDepth] nvarchar(32) NOT NULL,
    [WeeklyHours] nvarchar(16) NOT NULL,
    [LearningStyle] nvarchar(32) NOT NULL,
    [ProjectGoal] nvarchar(1000) NOT NULL,
    [CreatedAt] datetime2 NOT NULL,
    [UpdatedAt] datetime2 NOT NULL,
    CONSTRAINT [PK_OnboardingProfiles] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_OnboardingProfiles_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
);

-- Força a relação 1:1 no Onboarding, garantindo apenas um perfil por usuário
CREATE UNIQUE INDEX [IX_OnboardingProfiles_UserId] ON [OnboardingProfiles] ([UserId]);

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20260604073349_AddAiFeatures', N'10.0.5');

COMMIT;
GO
